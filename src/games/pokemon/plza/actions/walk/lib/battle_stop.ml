module Failure = Engine_run.Failure

let battle_on_screen = Failure.cause "battle_on_screen" "battle on screen"
let reads_in_a_row = 2

let streak ~stop_on_battle streak (screen : Screen.t) =
  if stop_on_battle && screen.battle then streak + 1 else 0

let holds streak = streak >= reads_in_a_row

let stopped log walk ~held_ms =
  log
    (Printf.sprintf
       "[PLZA] %s: battle HUD showed after %d ms of the last leg: stopping \
        walk."
       walk held_ms);
  Error battle_on_screen

type game_steps = { read_screen : unit -> Screen.t; wait : int -> unit }

let looks = 8
let look_ms = 250
let window_ms = 2000.0

(* The first hit's time; the HUD again within the window holds. *)
let rec look steps n ~first_hit =
  if n >= looks then false
  else
    let screen = steps.read_screen () in
    match (screen.battle, first_hit) with
    | false, None -> false
    | true, Some t when screen.at_ms -. t <= window_ms -> true
    | seen, _ ->
        steps.wait look_ms;
        let first_hit = if seen then Some screen.at_ms else first_hit in
        look steps (n + 1) ~first_hit

let showing steps = look steps 0 ~first_hit:None
