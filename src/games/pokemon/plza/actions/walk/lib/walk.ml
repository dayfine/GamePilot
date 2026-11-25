open Plza_rules.Walk_args
module Failure = Engine_run.Failure

type game_steps = {
  submit : Wire.command -> unit;
  read_screen : unit -> Screen.t;
  log : string -> unit;
  log_detail : string -> unit;
}

type outcome = (unit, Failure.cause) result

let ( let* ) = Result.bind

(* The L tap that recentres the camera, and the tilt the story was recorded
   with; short releases run legs back to back. *)
let recenter_hold_ms = 100
let recenter_release_ms = 150
let face_tilt_ms = 150
let face_release_ms = 100

(* How long each slice of the held last leg is, between screen reads for its
   end. *)
let hold_slice_ms = 250

let recenter steps =
  steps.submit
    (Inputs.button Wire.L ~hold_ms:recenter_hold_ms
       ~release_ms:recenter_release_ms)

let tilt steps ~walk_only pace ~degrees ~duration_ms ~release_ms =
  match Inputs.tilt ~walk_only pace ~degrees ~duration_ms ~release_ms with
  | Ok input -> Ok (steps.submit input)
  | Error e -> Error (Failure.cause ~repeats:true "walk_stick" e)

(* Runs straight on, or at the leg's angle when steered. *)
let run steps ~walk_only ~degrees duration_ms =
  tilt steps ~walk_only Inputs.Run ~degrees ~duration_ms ~release_ms:0

(* L, a tilt toward the angle, then L again: the walk goes where the camera
   looks. *)
let face steps ~walk_only degrees =
  recenter steps;
  let* () =
    tilt steps ~walk_only Inputs.Walk ~degrees ~duration_ms:face_tilt_ms
      ~release_ms:face_release_ms
  in
  Ok (recenter steps)

(* A dropped facing or hold leaves the screen still. A walk into a wall reads
   still too, and plays its leg twice. *)
let play_checked steps what input =
  let* () = input () in
  if (steps.read_screen ()).screen_still then (
    steps.log
      (Printf.sprintf "[PLZA] walk: the screen stayed still after %s; once more"
         what);
    input ())
  else Ok ()

let recenter_before_steered_leg steps index leg =
  if index > 0 && leg.angle_deg <> 0.0 then recenter steps

let rec steer_legs steps ~walk_only ?(index = 0) = function
  | [] -> Ok ()
  | leg :: rest ->
      recenter_before_steered_leg steps index leg;
      let* () =
        if leg.walk_ms > 0 then
          run steps ~walk_only ~degrees:leg.angle_deg leg.walk_ms
        else Ok ()
      in
      steer_legs steps ~walk_only ~index:(index + 1) rest

(* "leg 2/5 turn 90 walk 1200 ms", as the C++ logs it. *)
let leg_label index count leg =
  Printf.sprintf "leg %d/%d turn %g" (index + 1) count leg.angle_deg
  ^ if leg.walk_ms > 0 then Printf.sprintf " walk %d ms" leg.walk_ms else ""

let face_then_walk steps ~walk_only count index leg =
  let label = leg_label index count leg in
  let* () =
    if leg.angle_deg <> 0.0 then
      play_checked steps ("the turn of " ^ label) (fun () ->
          face steps ~walk_only leg.angle_deg)
    else Ok ()
  in
  if leg.walk_ms > 0 then
    play_checked steps ("the walk of " ^ label) (fun () ->
        run steps ~walk_only ~degrees:0.0 leg.walk_ms)
  else Ok ()

let rec face_then_walk_each steps ~walk_only count index = function
  | [] -> Ok ()
  | leg :: rest ->
      let* () = face_then_walk steps ~walk_only count index leg in
      face_then_walk_each steps ~walk_only count (index + 1) rest

let play_legs steps ~walk_only move =
  match move.style with
  | Steer -> steer_legs steps ~walk_only move.legs
  | Face_then_walk ->
      (* The read the first input is checked against. *)
      ignore (steps.read_screen ());
      face_then_walk_each steps ~walk_only (List.length move.legs) 0 move.legs

(* Reads the screen once the legs are done, so queued inputs have finished
    before the event ends, and logs what it shows. *)
let log_final_screen steps walk =
  let screen = steps.read_screen () in
  steps.log
    (Printf.sprintf "[PLZA] %s: legs done, screen now: %s" walk
       (Screen.describe screen))

let all_but_last legs = List.filteri (fun i _ -> i < List.length legs - 1) legs
let last legs = List.nth legs (List.length legs - 1)

let play_legs_but_last_walk steps ~walk_only move =
  match (move.legs, move.style) with
  | [], _ -> Ok ()
  | legs, Steer ->
      let head = all_but_last legs in
      let* () = steer_legs steps ~walk_only head in
      Ok (recenter_before_steered_leg steps (List.length head) (last legs))
  | legs, Face_then_walk ->
      let head = all_but_last legs @ [ { (last legs) with walk_ms = 0 } ] in
      play_legs steps ~walk_only { move with legs = head }

let hold_last_leg steps ~walk_only move slice =
  match (move.style, move.legs) with
  | Steer, (_ :: _ as legs) ->
      run steps ~walk_only ~degrees:(last legs).angle_deg slice
  | _ -> run steps ~walk_only ~degrees:0.0 slice

(* How the last leg's slices came out: [Ended] with the walk's outcome, or
   [Spent] once the hold's budget is spent, with the hold. *)
type last_leg = Ended of outcome | Spent of Last_leg_hold.t

let outcome_of (verdict : Last_leg_end.verdict) =
  match verdict with
  | Walk_on -> None
  | Ended -> Some (Ok ())
  | Failed cause -> Some (Error cause)

let rec slice_last_leg steps ~walk_only move ~check ~budget hold =
  if not (Last_leg_hold.unfinished hold) then Ok (Spent hold)
  else
    let sliced = Last_leg_hold.sliced_ms hold in
    let slice =
      if sliced < budget then min hold_slice_ms (budget - sliced)
      else hold_slice_ms
    in
    let* () = hold_last_leg steps ~walk_only move slice in
    let screen = steps.read_screen () in
    let hold = Last_leg_hold.add_slice hold slice ~read_at:screen.at_ms in
    match outcome_of (check screen ~held_ms:(Last_leg_hold.sliced_ms hold)) with
    | Some ended -> Ok (Ended ended)
    | None -> slice_last_leg steps ~walk_only move ~check ~budget hold

(* Plays all legs but the last walk, then slices the last leg until [check]
   ends it or the hold's budget is spent. *)
let walk_last_leg steps ~walk_only move ~check =
  let budget = match move.legs with [] -> 0 | legs -> (last legs).walk_ms in
  let* () = play_legs_but_last_walk steps ~walk_only move in
  slice_last_leg steps ~walk_only move ~check ~budget
    (Last_leg_hold.start budget)

let talk_game_steps steps : Talk_prompt.game_steps =
  {
    submit = steps.submit;
    read_screen = steps.read_screen;
    log = steps.log;
    log_detail = steps.log_detail;
  }

(* How long a walk into a talk looks for the prompt after its last leg. *)
let talk_tail_ms = 1000
let talk_poll_ms = 250
let talk_retry_gap_ms = 1000

let talk_at_prompt steps walk ~held_ms =
  Talk_prompt.talk (talk_game_steps steps) walk ~held_ms

let prompt_steady steps walk =
  let steady =
    (steps.read_screen ()).interact_prompt
    && Talk_prompt.steady (talk_game_steps steps)
  in
  if steady then
    steps.log
      (Printf.sprintf "[PLZA] %s: the A prompt shows before the walk: no walk."
         walk);
  steady

(* Only a walk of one straight leg to the first A prompt ahead. *)
let prompt_before_walking steps walk move =
  match move.legs with
  | [ { angle_deg = 0.0; _ } ] -> prompt_steady steps walk
  | _ -> false

let no_talk walk =
  Failure.cause "walk_no_end"
    (Printf.sprintf "%s: no talk started within %d ms after the last leg" walk
       talk_tail_ms)

(* After the legs: up to 1 s of reads for the prompt, A on it. *)
let rec talk_tail steps walk ~held_ms tail =
  if tail >= talk_tail_ms then Error (no_talk walk)
  else if not (steps.read_screen ()).interact_prompt then (
    steps.submit (Inputs.wait talk_poll_ms);
    talk_tail steps walk ~held_ms (tail + talk_poll_ms))
  else
    match talk_at_prompt steps walk ~held_ms with
    | Some ended -> ended
    | None -> talk_tail steps walk ~held_ms (tail + talk_retry_gap_ms)

let talk_check steps walk ~after_legs (screen : Screen.t) ~held_ms :
    Last_leg_end.verdict =
  if after_legs || not screen.interact_prompt then Walk_on
  else
    match talk_at_prompt steps walk ~held_ms with
    | Some (Ok ()) -> Ended
    | Some (Error cause) -> Failed cause
    | None -> Walk_on

(* A walk into a talk, as PokemonLZA_AutoStoryWalks.cpp walks it. *)
let walk_into_talk steps ~walk_only walk move ~after_legs =
  let early =
    if prompt_before_walking steps walk move then
      talk_at_prompt steps walk ~held_ms:0
    else None
  in
  match early with
  | Some ended -> ended
  | None -> (
      match
        walk_last_leg steps ~walk_only move
          ~check:(talk_check steps walk ~after_legs)
      with
      | Error failure -> Error failure
      | Ok (Ended outcome) -> outcome
      | Ok (Spent hold) ->
          talk_tail steps walk ~held_ms:(Last_leg_hold.sliced_ms hold) 0)

let end_check steps walk ~earliest_end_ms = function
  | Scene -> Last_leg_end.check_scene steps.log walk
  | Event event ->
      Last_leg_end.check_end_event ~log:steps.log ~log_detail:steps.log_detail
        ~prompt_steady:(fun () -> Talk_prompt.steady (talk_game_steps steps))
        walk event ~earliest_end_ms
  | Talk _ -> fun _ ~held_ms:_ -> Last_leg_end.Walk_on

(* As PokemonLZA_AutoStoryWalks.cpp ends a walk before it walks: a walk of
   one straight leg to the first A
   prompt ahead, with no earliest end, does not walk when it already shows. *)
let ends_before_walking steps walk move ~until ~earliest_end_ms =
  match until with
  | Event Prompt when earliest_end_ms = 0 ->
      prompt_before_walking steps walk move
  | _ -> false

let walk_last_leg_to_event steps ~walk_only walk move ~until ~earliest_end_ms =
  match
    walk_last_leg steps ~walk_only move
      ~check:(end_check steps walk ~earliest_end_ms until)
  with
  | Error failure -> Error failure
  | Ok (Ended outcome) -> outcome
  | Ok (Spent hold) ->
      Error
        (Last_leg_end.timed_out walk until
           ~elapsed_ms:(Last_leg_hold.elapsed_ms hold))

let walk_to_event steps ~walk_only walk move ~until ~earliest_end_ms =
  if ends_before_walking steps walk move ~until ~earliest_end_ms then Ok ()
  else walk_last_leg_to_event steps ~walk_only walk move ~until ~earliest_end_ms

let walk_to_end steps ~walk_only walk move ~until ~earliest_end_ms =
  match until with
  | Talk { after_legs } -> walk_into_talk steps ~walk_only walk move ~after_legs
  | Scene | Event _ ->
      walk_to_event steps ~walk_only walk move ~until ~earliest_end_ms

let run_event steps ~walk_only walk (args : Plza_rules.Walk_args.t) =
  if args.move.wait_before_ms > 0 then
    steps.submit (Inputs.wait args.move.wait_before_ms);
  let { submit; read_screen; log; log_detail } = steps in
  let free = Free_control_wait.screen_game_steps ~submit ~read_screen ~log in
  let* () = Free_control_wait.wait free walk in
  let face = Face_heading.screen_game_steps ~submit ~read_screen ~log_detail in
  let* () =
    Option.fold ~none:(Ok ()) ~some:(Face_heading.face face) args.heading_deg
  in
  match args.until with
  | Some until ->
      walk_to_end steps ~walk_only walk args.move ~until
        ~earliest_end_ms:args.earliest_end_ms
  | None ->
      let* () = play_legs steps ~walk_only args.move in
      Ok (log_final_screen steps walk)
