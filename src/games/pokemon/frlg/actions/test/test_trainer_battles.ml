(* Trainer_battles.run on fake game steps: battles in a row, then the settle;
   a battle not won, and one that never comes. *)

open Frlg_actions
module B = Frlg_battle
module Failure = Pokemon_engine.Failure

let case name input expectation = { Table_test.name; input; expectation }
let over = B.Scripted_battle.Over B.Scripted_battle.empty_summary

let fainted =
  B.Scripted_battle.Failed
    {
      why = "a member fainted and the script sends in no more";
      summary = B.Scripted_battle.empty_summary;
    }

(* The fake game: [comes] says whether battle i (from 1) starts, [fights] its
   outcome; every step is written down. *)
let play ?(comes = fun _ -> true) ?(fights = fun _ -> over) battles () =
  let calls = ref [] and n = ref 0 in
  let note s = calls := s :: !calls in
  let game_steps : Trainer_battles.game_steps =
    {
      await_battle =
        (fun () ->
          incr n;
          note (Printf.sprintf "await %d" !n);
          if comes !n then Ok ()
          else Error (Failure.cause "no_battle" "quiet overworld"));
      fight =
        (fun _ ->
          note "fight";
          fights !n);
      settle =
        (fun () ->
          note "settle";
          Ok ());
      log = ignore;
    }
  in
  let result =
    match Trainer_battles.run game_steps ~battles with
    | Ok (Won k) -> Printf.sprintf "won %d" k
    | Ok (Lost { battle; why }) -> Printf.sprintf "lost %d (%s)" battle why
    | Error (c : Failure.cause) -> "error " ^ c.code
  in
  String.concat ", " (List.rev !calls) ^ " -> " ^ result

let failure_code outcome () =
  match Trainer_battles.failure outcome with
  | Ok () -> "ok"
  | Error (c : Failure.cause) -> c.code ^ ": " ^ c.detail

let cases =
  [
    case "the Bikers: four battles, then the lines after the last" (play 4)
      "await 1, fight, await 2, fight, await 3, fight, await 4, fight, settle \
       -> won 4";
    case "the lead faints in the second battle: lost, nothing after"
      (play ~fights:(fun n -> if n = 2 then fainted else over) 4)
      "await 1, fight, await 2, fight -> lost 2 (a member fainted and the \
       script sends in no more)";
    case "the third battle never comes"
      (play ~comes:(fun n -> n < 3) 4)
      "await 1, fight, await 2, fight, await 3 -> error no_battle";
    case "won passes" (failure_code (Won 4)) "ok";
    case "lost fails as battle_lost"
      (failure_code (Lost { battle = 2; why = "fainted" }))
      "battle_lost: trainer battle 2: fainted";
    case "the script: the lead's four slots, nobody sent in, NO to a YES/NO"
      (fun () ->
        let s = Trainer_battles.script in
        Printf.sprintf "%s, %d send-ins, use next %b"
          (match s.fallback with
          | Attack { slots; _ } ->
              "attack " ^ String.concat " " (List.map string_of_int slots)
          | _ -> "other")
          (List.length s.send_ins) s.use_next)
      "attack 0 1 2 3, 0 send-ins, use next false";
  ]

let () = Table_test.run "trainer battles" cases
