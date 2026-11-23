(* The grind action: its args and strategies (pure), and its loop on a fake rig
   whose battles answer from a list driver, so a switch-trick battle with a
   level-up's move learn runs through the real Scripted_battle and the
   strategy's script. *)

open Frlg_actions
module B = Frlg_battle

let case name input expectation = { Case_table.name; input; expectation }
let strategies = Result.get_ok (Grind_plan.load_strategies ())
let obj json = Grid_maps.Json_field.as_object "" (Yojson.Safe.from_string json)

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
  | Error c -> Story.Failure.cause_to_string c

let heal_name : Grind_plan.heal -> string = function
  | Nurse g -> "nurse at " ^ Story.Pose.grid_to_string g
  | Pad g -> "pad at " ^ Story.Pose.grid_to_string g

let strategy name () =
  match
    List.find_opt (fun (s : Grind_plan.strategy) -> s.name = name) strategies
  with
  | None -> "none"
  | Some s ->
      Printf.sprintf "spot %s; heal every %d, %s"
        (Story.Pose.grid_to_string s.spot)
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

(* The fake rig: a party, the moves the summary reads, and a list of battles,
   each the events a list driver reports and the moves it is offered. *)
type fake_battle = {
  events : B.Battle_driver.event list;
  offered : string option list;
}

let list_driver (b : fake_battle) calls : B.Battle_driver.t =
  let events = Queue.of_seq (List.to_seq b.events) in
  let offered = Queue.of_seq (List.to_seq b.offered) in
  let call s = calls := s :: !calls in
  let take q d = Option.value (Queue.take_opt q) ~default:d in
  {
    next_event = (fun ~timeout_ms:_ -> take events B.Battle_driver.Timed_out);
    use_move =
      (fun ~slot ~target:_ ~expect:_ ->
        call (Printf.sprintf "move %d" slot);
        Chosen);
    switch_to =
      (fun ~slot ->
        call (Printf.sprintf "switch %d" slot);
        true);
    send_in =
      (fun ~slot ->
        call (Printf.sprintf "send %d" slot);
        true);
    run = (fun () -> call "run");
    use_item = (fun _ -> true);
    answer_move_learn =
      (fun learn ->
        let move = take offered None in
        let result : B.Battle_driver.learned =
          match learn with
          | Forget_for { move = want; slot } when move = Some want ->
              Learned { slot; move }
          | _ -> Not_learned { offered = move }
        in
        call ("learn: " ^ B.Battle_driver.describe_learned result);
        result);
    answer_use_next = (fun _ -> ());
  }

let flow ~party ~known battles plan () =
  let calls = ref [] in
  let call s = calls := s :: !calls in
  let party = ref (Party_roster.of_list party) in
  let battles = Queue.of_seq (List.to_seq battles) in
  let rig : Grind.rig =
    {
      slot_of = (fun s -> Party_roster.slot_of !party s);
      known_moves =
        (fun ~slot ->
          call (Printf.sprintf "summary %d" slot);
          known);
      swap =
        (fun a b ->
          call (Printf.sprintf "swap %d %d" a b);
          party := Party_roster.swap !party a b);
      go_to = (fun g -> call ("go " ^ Story.Pose.grid_to_string g));
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
                      prompts = 0;
                      learned = [];
                      unread = 0;
                    };
                }
          | Some b -> B.Scripted_battle.run (list_driver b calls) script);
      log = ignore;
    }
  in
  let result =
    match Grind.run rig plan with
    | () -> "ok"
    | exception Menu_input.Action_failed c ->
        "failed " ^ Story.Failure.cause_to_string c
  in
  String.concat "; " (List.rev !calls) ^ " => " ^ result

let party = [ "blastoise"; "mr-mime"; "farfetchd" ]

(* Switch on turn 1, the sweeper's KO, a level up that offers a move. *)
let won ?(offered = []) () =
  let learns = List.map (fun _ -> B.Battle_driver.Move_learn) offered in
  {
    events =
      B.Battle_driver.[ Action_menu; Action_menu ]
      @ learns
      @ [ B.Battle_driver.Battle_over ];
    offered;
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
       learning Recycle"
      (flow ~party ~known:[ "barrier"; "confusion" ]
         [
           won ~offered:[ Some "light-screen" ] ();
           won ~offered:[ Some "recycle" ] ();
         ]
         (plan mimien_args))
      "summary 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; switch 1; \
       move 0; learn: not learned: light-screen; spin; switch 1; move 0; \
       learn: learned recycle over move 0 => ok";
    case "Victory Road: the nurse after 7 battles, then back to the spot"
      (flow ~party ~known:[]
         (List.init 8 (fun _ -> won ()) @ [ won ~offered:[ Some "recycle" ] () ])
         (plan mimien_args))
      "summary 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; switch 1; \
       move 0; spin; switch 1; move 0; spin; switch 1; move 0; spin; switch 1; \
       move 0; spin; switch 1; move 0; spin; switch 1; move 0; spin; switch 1; \
       move 0; heal nurse at IndigoPlateau_PokemonCenter_1F (13, 12) north; go \
       VictoryRoad_2F (45, 10) west; spin; switch 1; move 0; spin; switch 1; \
       move 0; learn: learned recycle over move 0 => ok";
    case "out of battles"
      (flow ~party ~known:[] [ won (); won () ] tight)
      "summary 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; switch 1; \
       move 0; spin; switch 1; move 0 => failed grind_out_of_battles: mr-mime \
       did not learn recycle in 2 battles";
    case "a failed battle fails the action"
      (flow ~party ~known:[]
         [ { events = [ B.Battle_driver.Action_menu ]; offered = [] } ]
         (plan mimien_args))
      "summary 2; swap 2 1; go VictoryRoad_2F (45, 10) west; spin; switch 1 => \
       failed grind_battle_failed: battle 1: no battle event within 60000 ms";
    case "the grinder missing"
      (flow ~party:[ "blastoise" ] ~known:[] [] (plan mimien_args))
      " => failed not_in_party: mr-mime is not in the party";
  ]

let () = Case_table.run "grind" (decoding @ decisions @ flows)
