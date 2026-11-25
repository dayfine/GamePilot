open Plza_terms.Walk_args
module Failure = Engine_run.Failure

type game_steps = {
  submit : Wire.command -> unit;
  look : unit -> Walk_look.t;
  log : string -> unit;
  log_detail : string -> unit;
}

type outcome = (unit, Failure.cause) result

let ( let* ) = Result.bind

(* The L tap that recentres the camera, and the tilt the story was recorded
   with; short releases run legs back to back. *)
let recenter_hold_ms = 100
let recenter_release_ms = 150
let turn_tilt_ms = 150
let turn_release_ms = 100

(* How long each slice of the held last leg is, between looks for its end. *)
let hold_slice_ms = 250

let recenter steps =
  steps.submit
    (Stick_input.button Wire.L ~hold_ms:recenter_hold_ms
       ~release_ms:recenter_release_ms)

let stick steps ~walk_only pace ~degrees ~duration_ms ~release_ms =
  match Stick_input.stick ~walk_only pace ~degrees ~duration_ms ~release_ms with
  | Ok input -> Ok (steps.submit input)
  | Error e -> Error (Failure.cause ~repeats:true "walk_stick" e)

(* Runs straight on, or at the leg's angle when held. *)
let run steps ~walk_only ~degrees duration_ms =
  stick steps ~walk_only Stick_input.Run ~degrees ~duration_ms ~release_ms:0

(* story_turn, then L: the walk goes where the camera looks. *)
let turn_and_recenter steps ~walk_only degrees =
  recenter steps;
  let* () =
    stick steps ~walk_only Stick_input.Walk ~degrees ~duration_ms:turn_tilt_ms
      ~release_ms:turn_release_ms
  in
  Ok (recenter steps)

(* A dropped turn or hold leaves the screen still. A walk into a wall reads
   still too, and plays its leg twice. *)
let play_checked steps what input =
  let* () = input () in
  if (steps.look ()).screen_still then (
    steps.log
      (Printf.sprintf "[PLZA] walk: the screen stayed still after %s; once more"
         what);
    input ())
  else Ok ()

let recenter_before_held_leg steps index leg =
  if index > 0 && leg.turn <> 0.0 then recenter steps

let rec run_held_legs steps ~walk_only ?(index = 0) = function
  | [] -> Ok ()
  | leg :: rest ->
      recenter_before_held_leg steps index leg;
      let* () =
        if leg.walk_ms > 0 then
          run steps ~walk_only ~degrees:leg.turn leg.walk_ms
        else Ok ()
      in
      run_held_legs steps ~walk_only ~index:(index + 1) rest

(* "leg 2/5 turn 90 walk 1200 ms" *)
let leg_label index count leg =
  Printf.sprintf "leg %d/%d turn %g" (index + 1) count leg.turn
  ^ if leg.walk_ms > 0 then Printf.sprintf " walk %d ms" leg.walk_ms else ""

let play_leg steps ~walk_only count index leg =
  let label = leg_label index count leg in
  let* () =
    if leg.turn <> 0.0 then
      play_checked steps ("the turn of " ^ label) (fun () ->
          turn_and_recenter steps ~walk_only leg.turn)
    else Ok ()
  in
  if leg.walk_ms > 0 then
    play_checked steps ("the walk of " ^ label) (fun () ->
        run steps ~walk_only ~degrees:0.0 leg.walk_ms)
  else Ok ()

let rec play_legs steps ~walk_only count index = function
  | [] -> Ok ()
  | leg :: rest ->
      let* () = play_leg steps ~walk_only count index leg in
      play_legs steps ~walk_only count (index + 1) rest

let run_story_move steps ~walk_only move =
  match move.style with
  | Held -> run_held_legs steps ~walk_only move.legs
  | Turn_then_walk ->
      (* The look the first input is checked against. *)
      ignore (steps.look ());
      play_legs steps ~walk_only (List.length move.legs) 0 move.legs

let finish_walk steps walk =
  let look = steps.look () in
  steps.log
    (Printf.sprintf "[PLZA] %s: legs done, screen now: %s" walk
       (Walk_look.events look))

let all_but_last legs = List.filteri (fun i _ -> i < List.length legs - 1) legs
let last legs = List.nth legs (List.length legs - 1)

let run_story_move_but_last_walk steps ~walk_only move =
  match (move.legs, move.style) with
  | [], _ -> Ok ()
  | legs, Held ->
      let head = all_but_last legs in
      let* () = run_held_legs steps ~walk_only head in
      Ok (recenter_before_held_leg steps (List.length head) (last legs))
  | legs, Turn_then_walk ->
      let head = all_but_last legs @ [ { (last legs) with walk_ms = 0 } ] in
      run_story_move steps ~walk_only { move with legs = head }

let hold_last_leg steps ~walk_only move slice =
  match (move.style, move.legs) with
  | Held, (_ :: _ as legs) ->
      run steps ~walk_only ~degrees:(last legs).turn slice
  | _ -> run steps ~walk_only ~degrees:0.0 slice

(* How the last leg's looks came out: [Ended] with the walk's outcome, or
   [Spent] once the hold's budget is spent, with the hold. *)
type last_leg = Ended of outcome | Spent of Last_leg_hold.t

let rec slice_last_leg steps ~walk_only move ~on_look ~budget hold =
  if not (Last_leg_hold.holding hold) then Ok (Spent hold)
  else
    let sliced = Last_leg_hold.sliced hold in
    let slice =
      if sliced < budget then min hold_slice_ms (budget - sliced)
      else hold_slice_ms
    in
    let* () = hold_last_leg steps ~walk_only move slice in
    let look = steps.look () in
    let hold = Last_leg_hold.held_slice hold slice ~look_at:look.at_ms in
    match on_look look (Last_leg_hold.sliced hold) with
    | Some ended -> Ok (Ended ended)
    | None -> slice_last_leg steps ~walk_only move ~on_look ~budget hold

(* Runs all legs but the last walk, then slices the last leg until [on_look]
   ends it or the hold's budget is spent. *)
let walk_last_leg steps ~walk_only move ~on_look =
  let budget = match move.legs with [] -> 0 | legs -> (last legs).walk_ms in
  let* () = run_story_move_but_last_walk steps ~walk_only move in
  slice_last_leg steps ~walk_only move ~on_look ~budget
    (Last_leg_hold.start budget)

let walk_until steps ~walk_only walk move ~until ~end_after_ms =
  let on_look =
    match until with
    | Scene -> Walk_ends.scene_look steps.log walk
    | Event event ->
        Walk_ends.end_event_look ~log:steps.log ~log_detail:steps.log_detail
          walk event ~end_after_ms
  in
  match walk_last_leg steps ~walk_only move ~on_look with
  | Error failure -> Error failure
  | Ok (Ended outcome) -> outcome
  | Ok (Spent hold) ->
      Error (Walk_ends.no_end walk until (Last_leg_hold.elapsed hold))

let free_control_steps steps =
  {
    Free_control.look = steps.look;
    wait = (fun ms -> steps.submit (Stick_input.wait ms));
    log = steps.log;
  }

let walk_step steps ~walk_only walk (args : Plza_terms.Walk_args.t) =
  if args.move.wait_first_ms > 0 then
    steps.submit (Stick_input.wait args.move.wait_first_ms);
  let* () = Free_control.check_can_walk (free_control_steps steps) walk in
  match args.until with
  | Some until ->
      walk_until steps ~walk_only walk args.move ~until
        ~end_after_ms:args.end_after_ms
  | None ->
      let* () = run_story_move steps ~walk_only args.move in
      Ok (finish_walk steps walk)
