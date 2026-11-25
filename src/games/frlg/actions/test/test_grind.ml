(* The grind action: its args and strategies (pure), and its loop on fake game
   steps whose battles answer from a list, so a switch-trick battle with a
   level-up's move learn runs through the real Scripted_battle and the
   strategy's script. *)

open Frlg_actions
module B = Frlg_battle

let case name input expectation = { Table_test.name; input; expectation }
let strategies = Result.get_ok (Grind_plan.load_strategies ())
let obj json = Json_field.as_object "" (Yojson.Safe.from_string json)

let mimien_args =
  {|{"species": "mr-mime", "target_level": 33, "learn_move": "recycle",
     "learn_slot": 1, "sweeper": "blastoise", "sweeper_moves": [1, 2],
     "max_battles": 120}|}

let with_field key value json =
  let fields = obj json in
  `Assoc ((key, value) :: List.remove_assoc key fields) |> Yojson.Safe.to_string

let plan json = Result.get_ok (Grind_plan.decode strategies (obj json))

let decode json () =
  match Grind_plan.decode strategies (obj json) with
  | Ok t -> Grind_plan.describe t
  | Error c -> Pokemon_engine.Failure.cause_to_string c

let heal_name : Grind_plan.heal -> string = function
  | Nurse g -> "nurse at " ^ Pokemon_engine.Pose_text.grid g
  | Pad g -> "pad at " ^ Pokemon_engine.Pose_text.grid g

let strategy name () =
  match
    List.find_opt (fun (s : Grind_plan.strategy) -> s.name = name) strategies
  with
  | None -> "none"
  | Some s ->
      Printf.sprintf "spot %s; heal every %d, %s"
        (Pokemon_engine.Pose_text.grid s.spot)
        s.heal_every (heal_name s.heal)

let decoding =
  [
    case "MIMIEN on the default strategy" (decode mimien_args)
      "mr-mime to Lv 33 for recycle (into move 1) at victory_road_2f, \
       blastoise fighting";
    case "the Tower fallback named"
      (decode (with_field "strategy" (`String "pokemon_tower_5f") mimien_args))
      "mr-mime to Lv 33 for recycle (into move 1) at pokemon_tower_5f, \
       blastoise fighting";
    case "an unknown strategy"
      (decode (with_field "strategy" (`String "cerulean_cave") mimien_args))
      "bad_args: grind: strategy cerulean_cave is not in grind_strategies.json.";
    case "one round: said so"
      (decode (with_field "round" (`Bool true) mimien_args))
      "mr-mime to Lv 33 for recycle (into move 1) at victory_road_2f, \
       blastoise fighting, one round";
    case "a learn slot out of range"
      (decode (with_field "learn_slot" (`Int 5) mimien_args))
      "bad_args: grind: learn_slot is 5, not a move slot (1-4).";
    case "Victory Road 2F: by the Route 23 exit, the Indigo Plateau nurse"
      (strategy "victory_road_2f")
      "spot VictoryRoad_2F (45, 10) west; heal every 7, nurse at \
       IndigoPlateau_PokemonCenter_1F (13, 12) north";
    case "Tower 5F: the PurifiedZone pad two tiles east, every battle"
      (strategy "pokemon_tower_5f")
      "spot PokemonTower_5F (8, 9) east; heal every 1, pad at PokemonTower_5F \
       (10, 9) east";
  ]

let solo_rejected () =
  let json =
    {|{"strategies": [{"name": "x", "spot": {"map": "M", "tile": [1, 2], "facing": "north"},
       "lead": "solo_when_sure", "heal": {"pad": {"map": "M", "tile": [1, 3], "facing": "north"}},
       "heal_every": 1}]}|}
  in
  match Grind_plan.strategies_of_json (Yojson.Safe.from_string json) with
  | Ok _ -> "ok"
  | Error e -> e

let met known () =
  string_of_bool (Grind_plan.met (plan mimien_args).goal ~known)

let heal_due since_heal () =
  string_of_bool (Grind_plan.heal_due (plan mimien_args).strategy ~since_heal)

let learn () =
  match (Grind_plan.battle_script (plan mimien_args)).learn with
  | Forget_for { move; slot } -> Printf.sprintf "forget %d for %s" slot move
  | Forget s -> Printf.sprintf "forget %d" s
  | Keep_moves -> "keep"

let decisions =
  [
    case "switch or solo: solo needs readers FireRed lacks" solo_rejected
      "grind_strategies.json: strategies[0].lead solo_when_sure needs a foe \
       species reader and the grinder's level, which FireRed lacks.";
    case "goal met: the grinder knows the move"
      (met [ "barrier"; "recycle"; "substitute" ])
      "true";
    case "goal not met: no Recycle yet" (met [ "barrier"; "confusion" ]) "false";
    case "heal: not after 6 battles at Victory Road" (heal_due 6) "false";
    case "heal: after 7" (heal_due 7) "true";
    case "move learn: YES for Recycle only, into move 1" learn
      "forget 0 for recycle";
  ]

(* The fake game steps: a party, the moves the summary reads, and a list of battles,
   each the events the list's battle steps report and the moves it is offered. *)
type fake_battle = {
  events : B.Battle.event list;
  offered : string option list;
  switch_ok : bool;  (** false: the sweeper fainted, the game refuses it *)
}

let fake_battle_game_steps (b : fake_battle) calls : B.Battle.game_steps =
  let events = Queue.of_seq (List.to_seq b.events) in
  let offered = Queue.of_seq (List.to_seq b.offered) in
  let call s = calls := s :: !calls in
  let take q d = Option.value (Queue.take_opt q) ~default:d in
  {
    next_event = (fun ~timeout_ms:_ -> take events B.Battle.Timed_out);
    use_move =
      (fun ~slot ~target:_ ~expect:_ ->
        call (Printf.sprintf "move %d" slot);
        Chosen);
    switch_to =
      (fun ~slot ->
        call (Printf.sprintf "switch %d" slot);
        b.switch_ok);
    send_in =
      (fun ~slot ->
        call (Printf.sprintf "send %d" slot);
        true);
    run = (fun () -> call "run");
    use_item = (fun _ -> true);
    answer_move_learn =
      (fun learn ->
        let move = take offered None in
        let result : B.Battle.learned =
          match learn with
          | Forget_for { move = want; slot } when move = Some want ->
              Learned { slot; move }
          | _ -> Not_learned { offered = move }
        in
        call ("learn: " ^ B.Battle.describe_learned result);
        result);
    answer_use_next = (fun _ -> ());
  }

(* The log lines a flow shows as calls: the ends' (capped, reached, skipped);
   with [~battle_lines], the per-battle ones too. *)
let contains line part =
  let n = String.length part in
  let rec from i =
    i + n <= String.length line && (String.sub line i n = part || from (i + 1))
  in
  from 0

let shown ~battle_lines line =
  String.starts_with ~prefix:"Grind: capped" line
  || String.starts_with ~prefix:"Grind: round over" line
  || contains line " could not come in"
  || contains line " reached Lv "
  || (contains line " already; skipped" && not (contains line " knows "))
  || (battle_lines && String.starts_with ~prefix:"Grind: battle" line)

(* [cap]: the runner's --grind-battles. [levels]: what the summary reads, one
   per read, in order ([None]: not read); the last one again once used up. *)
let flow ?cap ?(battle_lines = false) ?(levels = [ Some 9 ]) ~party ~known
    battles plan () =
  let calls = ref [] in
  let call s = calls := s :: !calls in
  let party = ref (Party_roster.of_list party) in
  let battles = Queue.of_seq (List.to_seq battles) in
  let levels = ref levels in
  let read_level ~slot =
    let level = List.hd !levels in
    if List.tl !levels <> [] then levels := List.tl !levels;
    call
      (Printf.sprintf "Lv %s in %d"
         (Option.fold ~none:"?" ~some:string_of_int level)
         slot);
    level
  in
  let fake_game_steps : Grind.game_steps =
    {
      slot_of = (fun s -> Party_roster.slot_of !party s);
      known_moves =
        (fun ~slot ->
          call (Printf.sprintf "summary %d" slot);
          known);
      level = read_level;
      swap =
        (fun a b ->
          call (Printf.sprintf "swap %d %d" a b);
          party := Party_roster.swap !party a b);
      go_to = (fun g -> call ("go " ^ Pokemon_engine.Pose_text.grid g));
      heal = (fun h -> call ("heal " ^ heal_name h));
      find_battle = (fun () -> call "spin");
      battle =
        (fun script ->
          match Queue.take_opt battles with
          | None ->
              B.Scripted_battle.Failed
                {
                  why = "no battle";
                  summary =
                    {
                      menus = 0;
                      send_ins = 0;
                      refusals = 0;
                      switches_refused = 0;
                      prompts = 0;
                      learned = [];
                      unread = 0;
                    };
                }
          | Some b ->
              B.Scripted_battle.run (fake_battle_game_steps b calls) script);
      log = (fun line -> if shown ~battle_lines line then call line);
    }
  in
  let result =
    match Grind.run ?cap fake_game_steps plan with
    | () -> "ok"
    | exception Menu_input.Action_failed c ->
        "failed " ^ Pokemon_engine.Failure.cause_to_string c
  in
  String.concat "; " (List.rev !calls) ^ " => " ^ result

let party = [ "blastoise"; "mr-mime"; "farfetchd" ]
let lv n = Some n

(* Switch on turn 1, the sweeper's KO, a level up that offers a move. *)
let won ?(offered = []) () =
  let learns = List.map (fun _ -> B.Battle.Move_learn) offered in
  {
    events =
      B.Battle.[ Action_menu; Action_menu ] @ learns @ [ B.Battle.Battle_over ];
    offered;
    switch_ok = true;
  }

(* The sweeper fainted in the battle before (mg-04b testing 6, battle 4): the
   game refuses the switch, the lead runs. *)
let sweeper_down =
  {
    events = B.Battle.[ Action_menu; Action_menu; Battle_over ];
    offered = [];
    switch_ok = false;
  }

let chding =
  plan
    {|{"species": "farfetchd", "target_level": 21, "learn_move": "knock-off",
       "learn_slot": 1, "sweeper": "blastoise", "sweeper_moves": [1, 2],
       "max_battles": 60, "strategy": "pokemon_tower_5f"}|}

let tight = plan (with_field "max_battles" (`Int 2) mimien_args)

let flows =
  [
    case "CH'DING knows Knock Off: skipped after the summary"
      (flow ~party ~known:[ "knock-off"; "leer" ] [] chding)
      "summary 3 => ok";
    case
      "MIMIEN: arranged, to the spot, a battle declining Light Screen, one \
       learning Recycle at Lv 33"
      (flow
         ~levels:[ lv 31; lv 32; lv 33 ]
         ~party ~known:[ "barrier"; "confusion" ]
         [
           won ~offered:[ Some "light-screen" ] ();
           won ~offered:[ Some "recycle" ] ();
         ]
         (plan mimien_args))
      "summary 2; Lv 31 in 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; \
       switch 1; move 0; learn: not learned: light-screen; Lv 32 in 1; spin; \
       switch 1; move 0; learn: learned recycle over move 0; Lv 33 in 1; \
       Grind: mr-mime reached Lv 33 (target 33) in battle 2; learned recycle.; \
       heal nurse at IndigoPlateau_PokemonCenter_1F (13, 12) north; go \
       VictoryRoad_2F (45, 10) west => ok";
    case "Victory Road: the nurse after 7 battles, then back to the spot"
      (flow
         ~levels:(List.init 9 (fun _ -> lv 9) @ [ lv 33 ])
         ~party ~known:[]
         (List.init 8 (fun _ -> won ()) @ [ won ~offered:[ Some "recycle" ] () ])
         (plan mimien_args))
      "summary 2; Lv 9 in 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; \
       switch 1; move 0; Lv 9 in 1; spin; switch 1; move 0; Lv 9 in 1; spin; \
       switch 1; move 0; Lv 9 in 1; spin; switch 1; move 0; Lv 9 in 1; spin; \
       switch 1; move 0; Lv 9 in 1; spin; switch 1; move 0; Lv 9 in 1; spin; \
       switch 1; move 0; Lv 9 in 1; heal nurse at \
       IndigoPlateau_PokemonCenter_1F (13, 12) north; go VictoryRoad_2F (45, \
       10) west; spin; switch 1; move 0; Lv 9 in 1; spin; switch 1; move 0; \
       learn: learned recycle over move 0; Lv 33 in 1; Grind: mr-mime reached \
       Lv 33 (target 33) in battle 9; learned recycle.; heal nurse at \
       IndigoPlateau_PokemonCenter_1F (13, 12) north; go VictoryRoad_2F (45, \
       10) west => ok";
    case "out of battles"
      (flow ~party ~known:[] [ won (); won () ] tight)
      "summary 2; Lv 9 in 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; \
       switch 1; move 0; Lv 9 in 1; spin; switch 1; move 0; Lv 9 in 1 => \
       failed grind_out_of_battles: mr-mime did not reach Lv 33 in 2 battles \
       (Lv 9)";
    case "capped at 2: passes after battle 2, for testing"
      (flow ~cap:2 ~party ~known:[]
         [ won (); won (); won () ]
         (plan mimien_args))
      "summary 2; Lv 9 in 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; \
       switch 1; move 0; Lv 9 in 1; spin; switch 1; move 0; Lv 9 in 1; Grind: \
       capped at 2 battles for testing: mr-mime is Lv 9, not 33 => ok";
    case "capped at 8 at Victory Road: the heal after 7 comes before battle 8"
      (flow ~cap:8 ~party ~known:[]
         (List.init 9 (fun _ -> won ()))
         (plan mimien_args))
      "summary 2; Lv 9 in 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; \
       switch 1; move 0; Lv 9 in 1; spin; switch 1; move 0; Lv 9 in 1; spin; \
       switch 1; move 0; Lv 9 in 1; spin; switch 1; move 0; Lv 9 in 1; spin; \
       switch 1; move 0; Lv 9 in 1; spin; switch 1; move 0; Lv 9 in 1; spin; \
       switch 1; move 0; Lv 9 in 1; heal nurse at \
       IndigoPlateau_PokemonCenter_1F (13, 12) north; go VictoryRoad_2F (45, \
       10) west; spin; switch 1; move 0; Lv 9 in 1; Grind: capped at 8 battles \
       for testing: mr-mime is Lv 9, not 33 => ok";
    case "a cap above max_battles: running out still fails"
      (flow ~cap:5 ~party ~known:[] [ won (); won () ] tight)
      "summary 2; Lv 9 in 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; \
       switch 1; move 0; Lv 9 in 1; spin; switch 1; move 0; Lv 9 in 1 => \
       failed grind_out_of_battles: mr-mime did not reach Lv 33 in 2 battles \
       (Lv 9)";
    case "a failed battle fails the action"
      (flow ~party ~known:[]
         [
           { events = [ B.Battle.Action_menu ]; offered = []; switch_ok = true };
         ]
         (plan mimien_args))
      "summary 2; Lv 9 in 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; \
       switch 1 => failed grind_battle_failed: battle 1: no battle event \
       within 60000 ms";
    case "the sweeper refused (fainted): run, heal, back to the spot, on"
      (flow ~cap:3 ~party ~known:[]
         [ won (); sweeper_down; won () ]
         (plan mimien_args))
      "summary 2; Lv 9 in 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; \
       switch 1; move 0; Lv 9 in 1; spin; switch 1; run; Lv 9 in 1; Grind: \
       battle 2: blastoise could not come in, ran.; heal nurse at \
       IndigoPlateau_PokemonCenter_1F (13, 12) north; go VictoryRoad_2F (45, \
       10) west; spin; switch 1; move 0; Lv 9 in 1; Grind: capped at 3 battles \
       for testing: mr-mime is Lv 9, not 33 => ok";
    case "the grinder missing"
      (flow ~party:[ "blastoise" ] ~known:[] [] (plan mimien_args))
      " => failed not_in_party: mr-mime is not in the party";
  ]

(* The C++'s stop logic (GrindRun::run()): the level read before the grind and
   after each battle. *)
let stops =
  let mimien = plan mimien_args in
  [
    case "reached already: Lv 34 before the grind, no walk out"
      (flow ~levels:[ lv 34 ] ~party ~known:[] [] mimien)
      "summary 2; Lv 34 in 2; Grind: mr-mime is Lv 34, at least 33 already; \
       skipped. => ok";
    case "target reached mid-run without the move: ends there, healed"
      (flow
         ~levels:[ lv 32; lv 33 ]
         ~party ~known:[]
         [ won ~offered:[ Some "light-screen" ] (); won () ]
         mimien)
      "summary 2; Lv 32 in 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; \
       switch 1; move 0; learn: not learned: light-screen; Lv 33 in 1; Grind: \
       mr-mime reached Lv 33 (target 33) in battle 1; did not learn recycle.; \
       heal nurse at IndigoPlateau_PokemonCenter_1F (13, 12) north; go \
       VictoryRoad_2F (45, 10) west => ok";
    case "the move learned below the target level: fights on to it"
      (flow
         ~levels:[ lv 31; lv 32; lv 33 ]
         ~party ~known:[]
         [ won ~offered:[ Some "recycle" ] (); won (); won () ]
         mimien)
      "summary 2; Lv 31 in 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; \
       switch 1; move 0; learn: learned recycle over move 0; Lv 32 in 1; spin; \
       switch 1; move 0; Lv 33 in 1; Grind: mr-mime reached Lv 33 (target 33) \
       in battle 2; learned recycle.; heal nurse at \
       IndigoPlateau_PokemonCenter_1F (13, 12) north; go VictoryRoad_2F (45, \
       10) west => ok";
    case "the cap first: Lv 33 would come in battle 3"
      (flow ~cap:2
         ~levels:[ lv 31; lv 31; lv 32; lv 33 ]
         ~party ~known:[]
         [ won (); won (); won () ]
         mimien)
      "summary 2; Lv 31 in 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; \
       switch 1; move 0; Lv 31 in 1; spin; switch 1; move 0; Lv 32 in 1; \
       Grind: capped at 2 battles for testing: mr-mime is Lv 32, not 33 => ok";
    case "unread before the grind: ends, no walk out"
      (flow ~levels:[ None ] ~party ~known:[] [] mimien)
      "summary 2; Lv ? in 2 => failed grind_level_unread: couldn't read \
       mr-mime's level before the grind";
    case "unread after a battle: ends there"
      (flow ~levels:[ lv 31; None ] ~party ~known:[] [ won (); won () ] mimien)
      "summary 2; Lv 31 in 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; \
       switch 1; move 0; Lv ? in 1 => failed grind_level_unread: couldn't read \
       mr-mime's level after battle 1";
    case "the battle's line: battle N of LIMIT, Lv L"
      (flow ~battle_lines:true
         ~levels:[ lv 32; lv 33 ]
         ~party ~known:[]
         [ won () ]
         mimien)
      "summary 2; Lv 32 in 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; \
       switch 1; move 0; Lv 33 in 1; Grind: battle 1 of 120, Lv 33 over (2 \
       menus, 0 send-ins, 0 refused, 0 prompts).; Grind: mr-mime reached Lv 33 \
       (target 33) in battle 1; did not learn recycle.; heal nurse at \
       IndigoPlateau_PokemonCenter_1F (13, 12) north; go VictoryRoad_2F (45, \
       10) west => ok";
  ]

(* One round (mg-04b's): from the nurse to the spot, heal_every battles or
   until the goal, then back to the nurse to heal, ending there. *)
let rounds =
  let round = plan (with_field "round" (`Bool true) mimien_args) in
  [
    case "a round stops at heal_every (7 at Victory Road), ending at the nurse"
      (flow
         ~levels:[ lv 9 ]
         ~party ~known:[]
         (List.init 8 (fun _ -> won ()))
         round)
      "summary 2; Lv 9 in 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; \
       switch 1; move 0; Lv 9 in 1; spin; switch 1; move 0; Lv 9 in 1; spin; \
       switch 1; move 0; Lv 9 in 1; spin; switch 1; move 0; Lv 9 in 1; spin; \
       switch 1; move 0; Lv 9 in 1; spin; switch 1; move 0; Lv 9 in 1; spin; \
       switch 1; move 0; Lv 9 in 1; Grind: round over after 7 battles: mr-mime \
       is Lv 9, not 33; heal nurse at IndigoPlateau_PokemonCenter_1F (13, 12) \
       north => ok";
    case
      "a round stops at the goal: Light Screen declined, Recycle learned in \
       battle 2 at Lv 33"
      (flow
         ~levels:[ lv 31; lv 32; lv 33 ]
         ~party ~known:[ "barrier" ]
         [
           won ~offered:[ Some "light-screen" ] ();
           won ~offered:[ Some "recycle" ] ();
           won ();
         ]
         round)
      "summary 2; Lv 31 in 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; \
       switch 1; move 0; learn: not learned: light-screen; Lv 32 in 1; spin; \
       switch 1; move 0; learn: learned recycle over move 0; Lv 33 in 1; \
       Grind: mr-mime reached Lv 33 (target 33) in battle 2; learned recycle.; \
       heal nurse at IndigoPlateau_PokemonCenter_1F (13, 12) north => ok";
    case "the goal met already (a resumed run): no walk, still at the nurse"
      (flow ~levels:[ lv 33 ] ~party ~known:[ "recycle" ] [] round)
      "summary 2 => ok";
    case "at the target level without the move: no round can teach it"
      (flow ~levels:[ lv 33 ] ~party ~known:[ "barrier" ] [] round)
      "summary 2; Lv 33 in 2 => failed grind_move_missed: mr-mime is Lv 33, at \
       least 33, and does not know recycle";
    case
      "the sweeper refused (fainted in battle 4, mg-04b testing 6): run, the \
       round ends at the nurse"
      (flow
         ~levels:[ lv 12 ]
         ~party ~known:[]
         [ won (); sweeper_down; won () ]
         round)
      "summary 2; Lv 12 in 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; \
       switch 1; move 0; Lv 12 in 1; spin; switch 1; run; Lv 12 in 1; Grind: \
       battle 2: blastoise could not come in, ran.; heal nurse at \
       IndigoPlateau_PokemonCenter_1F (13, 12) north => ok";
    case "capped at 2 for testing: 2 battles, then the nurse"
      (flow ~cap:2
         ~levels:[ lv 9 ]
         ~party ~known:[]
         [ won (); won (); won () ]
         round)
      "summary 2; Lv 9 in 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; \
       switch 1; move 0; Lv 9 in 1; spin; switch 1; move 0; Lv 9 in 1; Grind: \
       round over after 2 battles: mr-mime is Lv 9, not 33; heal nurse at \
       IndigoPlateau_PokemonCenter_1F (13, 12) north => ok";
  ]

(* The default strategy's walks on all of FireRed's maps, as a run loads them:
   the Victory Road 2F spot is reached by Route 23's top exit, a walk from
   Indigo Plateau with no Strength puzzle on the way. *)
module Route_target = Frlg_overworld.Route_target

let kanto =
  lazy
    (Frlg_overworld_fixtures.Frlg_world.world
       (Grid_maps.Map_file.runtime_names
          ~maps_dir:Frlg_overworld_fixtures.Frlg_world.maps_dir))

let victory_road =
  List.find
    (fun (s : Grind_plan.strategy) -> s.name = "victory_road_2f")
    strategies

let nurse_of (s : Grind_plan.strategy) =
  match s.heal with Nurse g | Pad g -> g

let pose_of (g : Pokemon_engine.Pose.grid) : Pokemon_engine.Pose.observed =
  { at_map = g.map; at_tile = List.hd g.tiles; faces = g.facing }

let legs_from (from : Pokemon_engine.Pose.observed) target =
  let w = Lazy.force kanto in
  Result.bind (Route_target.place_of w from) (fun place ->
      Route_target.plan w ~from:place ~facing:from.faces target)

(* The maps each press of the walk stands on, in order, including the ones a
   leg crosses without stopping. *)
let maps_crossed from target () =
  let w = Lazy.force kanto in
  let name (p : Grid_maps.Connected_maps.place) =
    (Grid_maps.Connected_maps.map w.maps p.map).name
  in
  let rec pressed place direction n acc =
    match (n, Frlg_overworld.Frlg_steps.press w place direction) with
    | 0, _ | _, None -> acc
    | n, Some step -> pressed step.next direction (n - 1) (name step.next :: acc)
  in
  let leg_maps acc (leg : _ Grid_planning.Leg.t) =
    match leg.kind with
    | Walk { tiles; _ } -> pressed leg.start leg.direction tiles acc
    | Face | Special_step _ -> name leg.finish :: acc
  in
  let rec dedupe = function
    | a :: (b :: _ as rest) when a = b -> dedupe rest
    | a :: rest -> a :: dedupe rest
    | [] -> []
  in
  match legs_from from target with
  | Error e -> "error: " ^ e
  | Ok legs ->
      List.fold_left leg_maps [ from.at_map ] legs
      |> List.rev |> dedupe |> String.concat " -> "

let indigo_landing =
  (Option.get
     (Fly_towns.find (Result.get_ok (Fly_towns.load ())) "IndigoPlateau"))
    .landing

(* Fly lands the player facing south, so the first leg south is held at once:
   a turn tap would be a step south, and every leg after it a tile off. *)
let first_hold from target () =
  let w = Lazy.force kanto in
  match legs_from from target with
  | Error e -> "error: " ^ e
  | Ok [] -> "no legs"
  | Ok (leg :: _) -> (
      match
        Frlg_overworld.Route_legs.move_of w Running ~facing:from.faces leg
      with
      | Ok (Hold { turn_first; _ }) ->
          Grid_geometry.Direction.name leg.direction
          ^ if turn_first then ", turn tap first" else ", no turn tap"
      | Ok (Turn d) -> "turn " ^ Grid_geometry.Direction.name d
      | Error e -> "error: " ^ e)

let routes =
  [
    case
      "victory_road_2f: Fly's landing to the spot, south by Route 23's top exit"
      (maps_crossed indigo_landing victory_road.spot)
      "IndigoPlateau_Exterior -> Route23 -> VictoryRoad_2F";
    case
      "victory_road_2f: Fly's landing faces south, the first hold has no turn \
       tap"
      (first_hold indigo_landing victory_road.spot)
      "south, no turn tap";
    case "victory_road_2f: the nurse to the spot"
      (maps_crossed (pose_of (nurse_of victory_road)) victory_road.spot)
      "IndigoPlateau_PokemonCenter_1F -> IndigoPlateau_Exterior -> Route23 -> \
       VictoryRoad_2F";
    case "victory_road_2f: the spot back to the nurse"
      (maps_crossed (pose_of victory_road.spot) (nurse_of victory_road))
      "VictoryRoad_2F -> Route23 -> IndigoPlateau_Exterior -> \
       IndigoPlateau_PokemonCenter_1F";
  ]

let () =
  Table_test.run "grind" (decoding @ decisions @ flows @ stops @ rounds @ routes)
