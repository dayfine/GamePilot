(* mg-05's two battle actions on fake game steps whose battles answer from a
   list, so the real Scripted_battle plays each action's script: the Blizzard
   PP drain (prepare_berry_pp) and Lea & Jed's double battle
   (mail_glitch_double_battle), as the fork's Route 16 run played them. *)

open Frlg_actions
open Frlg_level_up_fake
module B = Frlg_battle
module Battle = B.Battle

let case name input expectation = { Table_test.name; input; expectation }
let obj json = Json_field.as_object "" (Yojson.Safe.from_string json)

(* A battle as the list's fake game steps play it: the events it reports, and the result
   of each move chosen (default [Chosen]). *)
type fake_battle = {
  events : Battle.event list;
  moves : Battle.move_result list;
}

let take q d = Option.value (Queue.take_opt q) ~default:d

let fake_battle_game_steps (b : fake_battle) call : Battle.game_steps =
  let events = Queue.of_seq (List.to_seq b.events) in
  let moves = Queue.of_seq (List.to_seq b.moves) in
  {
    next_event = (fun ~timeout_ms:_ -> take events Battle.Timed_out);
    use_move =
      (fun ~slot ~target ~expect:_ ->
        let result = take moves Battle.Chosen in
        call
          (Printf.sprintf "move %d %s%s" slot
             (Battle.target_name target)
             (if result = Battle.Refused then " refused" else ""));
        result);
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
    level_up = Level_up_fake.fake_game_steps (Level_up_fake.game []);
    answer_use_next = (fun _ -> ());
  }

let no_battle : B.Scripted_battle.outcome =
  Failed { why = "no battle"; summary = B.Scripted_battle.empty_summary }

let outcome f =
  match f () with
  | () -> "ok"
  | exception Menu_input.Action_failed c ->
      "failed " ^ Pokemon_engine.Failure.cause_to_string c

let recorded f =
  let calls = ref [] in
  let call s = calls := s :: !calls in
  let result = outcome (fun () -> f call) in
  String.concat "; " (List.rev !calls) ^ " => " ^ result

let cause_or_ok = function
  | Ok _ -> "ok"
  | Error c -> Pokemon_engine.Failure.cause_to_string c

(* prepare_berry_pp *)

let blastoise_moves = [ "surf"; "blizzard"; "bite"; "strength" ]

let berry_args =
  {|{"species": "blastoise", "move": "blizzard", "backup_move": "surf", "pace": "west"}|}

let berry_plan = Result.get_ok (Berry_pp.decode (obj berry_args))

let drain ?(lead = "blastoise") ?(known = blastoise_moves) battles () =
  recorded (fun call ->
      let battles = Queue.of_seq (List.to_seq battles) in
      let fake_game_steps : Berry_pp.game_steps =
        {
          lead = (fun () -> Some lead);
          known_moves =
            (fun ~slot ->
              call (Printf.sprintf "summary %d" slot);
              known);
          find_battle = (fun () -> call "spin");
          battle =
            (fun script ->
              match Queue.take_opt battles with
              | None -> no_battle
              | Some b ->
                  B.Scripted_battle.run (fake_battle_game_steps b call) script);
          log = ignore;
        }
      in
      Berry_pp.run fake_game_steps berry_plan)

let won = { events = Battle.[ Action_menu; Battle_over ]; moves = [] }

(* Blizzard refused on the first menu: Surf instead, and the drain is done. *)
let ran_dry =
  {
    events = Battle.[ Action_menu; Action_menu; Battle_over ];
    moves = [ Battle.Refused ];
  }

let berry_pp_cases =
  [
    case "decode: the fork's mg-05a args"
      (fun () -> cause_or_ok (Berry_pp.decode (obj berry_args)))
      "ok";
    case "decode: no backup move"
      (fun () ->
        cause_or_ok
          (Berry_pp.decode
             (obj
                {|{"species": "blastoise", "move": "blizzard", "pace": "west"}|})))
      "bad_args: prepare_berry_pp: backup_move is missing.";
    case "decode: no way to pace (turning in place drifted off the grass)"
      (fun () ->
        cause_or_ok
          (Berry_pp.decode
             (obj
                {|{"species": "blastoise", "move": "blizzard", "backup_move": "surf"}|})))
      "bad_args: prepare_berry_pp: pace is missing.";
    case "Blizzard until the game refuses it, then Surf; done after that battle"
      (drain [ won; won; ran_dry ])
      "summary 1; spin; move 1 default; spin; move 1 default; spin; move 1 \
       default refused; move 0 default => ok";
    case "the wrong lead stops before any battle"
      (drain ~lead:"farfetchd" [])
      " => failed berry_pp_wrong_lead: farfetchd leads, not blastoise";
    case "the lead without the move"
      (drain ~known:[ "surf"; "bite" ] [])
      "summary 1 => failed berry_pp_missing_move: blastoise knows no blizzard";
    case "a failed battle fails the action"
      (drain [ { events = [ Battle.Action_menu ]; moves = [] } ])
      "summary 1; spin; move 1 default => failed berry_pp_battle_failed: \
       battle 1: no battle event within 60000 ms";
  ]

(* mail_glitch_double_battle *)

let battle_args =
  {|{"knock_off_species": "farfetchd", "recycle_species": "mr-mime", "sweeper": "blastoise",
     "depleted_move": "blizzard", "step_direction": "north"}|}

let battle_plan = Result.get_ok (Mail_glitch_battle.decode (obj battle_args))
let chding_moves = [ "knock-off"; "sand-attack"; "fury-attack"; "leer" ]
let mimien_moves = [ "barrier"; "recycle"; "psybeam"; "substitute" ]
let party = [| "farfetchd"; "blastoise"; "mr-mime"; "pidgey" |]

let moves_of slot =
  match slot with 1 -> chding_moves | 2 -> blastoise_moves | _ -> mimien_moves

(* The whole battle: two Berry-turn menus, four setup menus, then the sweep
   until it is over. *)
let double ?(restored = true) ?(party = party) battle () =
  recorded (fun call ->
      let fake_game_steps : Mail_glitch_battle.game_steps =
        {
          species_at = (fun slot -> Array.get party (slot - 1) |> Option.some);
          known_moves =
            (fun ~slot ->
              call (Printf.sprintf "summary %d" slot);
              moves_of slot);
          start_battle =
            (fun d -> call ("step " ^ Grid_geometry.Direction.name d));
          restored =
            (fun ~slot () ->
              call (Printf.sprintf "pp %d" slot);
              restored);
          battle =
            (fun wrap script ->
              B.Scripted_battle.run
                (wrap (fake_battle_game_steps battle call))
                script);
          after_battle = (fun () -> call "after");
          log = ignore;
        }
      in
      Mail_glitch_battle.run fake_game_steps battle_plan)

let menus n = List.init n (fun _ -> Battle.Action_menu)

let double_battle_cases =
  [
    case "slots: from the members' known moves"
      (fun () ->
        match
          Mail_glitch_battle.find_slots ~lead:chding_moves
            ~holder:blastoise_moves ~recycler:mimien_moves
            ~depleted_move:"blizzard"
        with
        | Ok s ->
            Printf.sprintf
              "knock off %d, sand attack %d, surf %d, bite %d, blizzard %d, \
               recycle %d"
              s.knock_off s.sand_attack s.surf s.bite s.depleted s.recycle
        | Error e -> e)
      "knock off 0, sand attack 1, surf 0, bite 2, blizzard 1, recycle 1";
    case "the fork's run: Berry turn, Knock Off, two switches, Recycle, sweep"
      (double { events = menus 9 @ [ Battle.Battle_over ]; moves = [] })
      "summary 1; summary 2; summary 3; step north; move 1 foe left; move 2 \
       foe left; move 0 ally; pp 1; switch 2; switch 2; move 1 default; move 0 \
       default; move 1 default; move 0 default; after => ok";
    case "the Berry did not restore Blizzard: stop before the switch"
      (double ~restored:false { events = menus 9; moves = [] })
      "summary 1; summary 2; summary 3; step north; move 1 foe left; move 2 \
       foe left; move 0 ally; pp 1 => failed double_battle_berry_not_consumed: \
       the depleted move shows no PP after the Berry turn";
    case "the party out of order"
      (double
         ~party:[| "blastoise"; "farfetchd"; "mr-mime" |]
         { events = []; moves = [] })
      " => failed double_battle_wrong_party: expected farfetchd, blastoise, \
       mr-mime in slots 1-3";
    case "a sweep that outlasts the limit fails the battle"
      (double { events = menus 30; moves = [] })
      (let sweep =
         List.init Mail_glitch_battle.sweep_menus (fun i ->
             if i mod 2 = 0 then "move 0 default" else "move 1 default")
       in
       "summary 1; summary 2; summary 3; step north; move 1 foe left; move 2 \
        foe left; move 0 ally; pp 1; switch 2; switch 2; move 1 default; "
       ^ String.concat "; " sweep
       ^ " => failed double_battle_failed: an action menu after the script's \
          last command");
  ]

let () =
  Table_test.run "mail_glitch_actions" (berry_pp_cases @ double_battle_cases)
