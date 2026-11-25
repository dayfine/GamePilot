(* Scene_battle.run on fake game steps: one battle a talk started, fought, and
   nothing pressed after it; a lost one, with and without may_lose. *)

open Frlg_actions
module B = Frlg_battle
module Failure = Pokemon_engine.Failure

let case name input expectation = { Table_test.name; input; expectation }
let over = B.Scripted_battle.Over B.Scripted_battle.empty_summary

let fainted =
  B.Scripted_battle.Failed
    { why = "the lead fainted"; summary = B.Scripted_battle.empty_summary }

let play ?(comes = true) ~fights ~may_lose () =
  let calls = ref [] in
  let note s = calls := s :: !calls in
  let game_steps : Trainer_battles.game_steps =
    {
      await_battle =
        (fun () ->
          note "await";
          if comes then Ok ()
          else Error (Failure.cause "no_battle" "quiet overworld"));
      fight =
        (fun _ ->
          note "fight";
          fights);
      settle =
        (fun () ->
          note "settle";
          Ok ());
      log = ignore;
    }
  in
  let result =
    match Scene_battle.run game_steps ~may_lose with
    | Ok () -> "ok"
    | Error (c : Failure.cause) -> c.code ^ ": " ^ c.detail
  in
  String.concat ", " (List.rev !calls) ^ " -> " ^ result

let cases =
  [
    case "Lostelle's Hypno: fought, the lines after left to the next event"
      (play ~fights:over ~may_lose:false)
      "await, fight -> ok";
    case "lost: battle_lost"
      (play ~fights:fainted ~may_lose:false)
      "await, fight -> battle_lost: trainer battle 1: the lead fainted";
    case "lost, where the plan may lose: passes"
      (play ~fights:fainted ~may_lose:true)
      "await, fight -> ok";
    case "no battle comes"
      (play ~comes:false ~fights:over ~may_lose:false)
      "await -> no_battle: quiet overworld";
  ]

let () = Table_test.run "scene battle" cases
