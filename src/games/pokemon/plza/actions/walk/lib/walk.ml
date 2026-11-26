open Plza_rules.Walk_args
module Failure = Engine_run.Failure

type game_steps = Leg_play.game_steps = {
  submit : Wire.command -> unit;
  read_screen : unit -> Walk_screen.t;
  log : string -> unit;
  log_detail : string -> unit;
}

type outcome = (unit, Failure.cause) result

let ( let* ) = Result.bind
let play_legs = Leg_play.play_legs

(* How long each slice of the held last leg is, between screen reads for its
   end. *)
let hold_slice_ms = 250

(* Reads the screen once the legs are done, so queued inputs have finished
    before the event ends, and logs what it shows. *)
let log_final_screen steps walk =
  let screen = steps.read_screen () in
  steps.log
    (Printf.sprintf "[PLZA] %s: legs done, screen now: %s" walk
       (Walk_screen.describe screen))

(* How the last leg's slices came out: [Ended] with the walk's outcome, or
   [Spent] once the hold's budget is spent, with the hold and the battle HUD's
   reads in a row so far. *)
type last_leg = Ended of outcome | Spent of Last_leg_hold.t * int

let outcome_of (verdict : Last_leg_end.verdict) =
  match verdict with
  | Walk_on -> None
  | Ended -> Some (Ok ())
  | Failed cause -> Some (Error cause)

(* The next slice: up to 250 ms, the rest of the budget last. *)
let next_slice ~budget hold =
  let sliced = Last_leg_hold.sliced_ms hold in
  if sliced < budget then min hold_slice_ms (budget - sliced) else hold_slice_ms

(* What one slice's read says: the walk's end, if any, and the battle HUD's
   reads in a row. *)
let slice_end steps ~stop_on_battle walk ~check ~streak screen ~held_ms =
  let streak = Battle_stop.streak ~stop_on_battle streak screen in
  if Battle_stop.holds streak then
    (Some (Battle_stop.stopped steps.log walk ~held_ms), streak)
  else (outcome_of (check screen ~held_ms), streak)

let rec slice_last_leg steps ~walk_only ~stop_on_battle walk move ~check ~budget
    ~streak hold =
  if not (Last_leg_hold.unfinished hold) then Ok (Spent (hold, streak))
  else
    let slice = next_slice ~budget hold in
    let* () = Leg_play.hold_last_leg steps ~walk_only move slice in
    let screen = steps.read_screen () in
    let hold = Last_leg_hold.add_slice hold slice ~read_at:screen.at_ms in
    let held_ms = Last_leg_hold.sliced_ms hold in
    match
      slice_end steps ~stop_on_battle walk ~check ~streak screen ~held_ms
    with
    | Some ended, _ -> Ok (Ended ended)
    | None, streak ->
        slice_last_leg steps ~walk_only ~stop_on_battle walk move ~check ~budget
          ~streak hold

(* Plays all legs but the last walk, then slices the last leg until [check]
   ends it, the battle HUD holds (with [stop_on_battle]) or the hold's budget
   is spent. *)
let walk_last_leg steps ~walk_only ~stop_on_battle walk move ~check =
  let budget = match List.rev move.legs with [] -> 0 | l :: _ -> l.walk_ms in
  let* () = Leg_play.play_legs_but_last_walk steps ~walk_only move in
  slice_last_leg steps ~walk_only ~stop_on_battle walk move ~check ~budget
    ~streak:0
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

(* After the legs: up to 1 s of reads for the prompt, A on it; the battle
   HUD's reads in a row carried on from the last leg's. *)
let rec talk_tail steps ~stop_on_battle walk ~held_ms ~streak tail =
  if tail >= talk_tail_ms then Error (no_talk walk)
  else talk_read steps ~stop_on_battle walk ~held_ms ~streak tail

and talk_read steps ~stop_on_battle walk ~held_ms ~streak tail =
  let screen = steps.read_screen () in
  let streak = Battle_stop.streak ~stop_on_battle streak screen in
  let next tail = talk_tail steps ~stop_on_battle walk ~held_ms ~streak tail in
  if Battle_stop.holds streak then Battle_stop.stopped steps.log walk ~held_ms
  else if not screen.interact_prompt then (
    steps.submit (Walk_inputs.wait talk_poll_ms);
    next (tail + talk_poll_ms))
  else
    match talk_at_prompt steps walk ~held_ms with
    | Some ended -> ended
    | None -> next (tail + talk_retry_gap_ms)

let talk_check steps walk ~after_legs (screen : Walk_screen.t) ~held_ms :
    Last_leg_end.verdict =
  if after_legs || not screen.interact_prompt then Walk_on
  else
    match talk_at_prompt steps walk ~held_ms with
    | Some (Ok ()) -> Ended
    | Some (Error cause) -> Failed cause
    | None -> Walk_on

(* The last leg's end, or the reads for the prompt after it. *)
let talk_after_last_leg steps ~stop_on_battle walk = function
  | Error failure -> Error failure
  | Ok (Ended outcome) -> outcome
  | Ok (Spent (hold, streak)) ->
      talk_tail steps ~stop_on_battle walk
        ~held_ms:(Last_leg_hold.sliced_ms hold)
        ~streak 0

(* A walk into a talk, as PokemonLZA_AutoStoryWalks.cpp walks it. *)
let walk_into_talk steps ~walk_only ~stop_on_battle walk move ~after_legs =
  let early =
    if prompt_before_walking steps walk move then
      talk_at_prompt steps walk ~held_ms:0
    else None
  in
  match early with
  | Some ended -> ended
  | None ->
      talk_after_last_leg steps ~stop_on_battle walk
        (walk_last_leg steps ~walk_only ~stop_on_battle walk move
           ~check:(talk_check steps walk ~after_legs))

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

let walk_last_leg_to_event steps ~walk_only ~stop_on_battle walk move ~until
    ~earliest_end_ms =
  match
    walk_last_leg steps ~walk_only ~stop_on_battle walk move
      ~check:(end_check steps walk ~earliest_end_ms until)
  with
  | Error failure -> Error failure
  | Ok (Ended outcome) -> outcome
  | Ok (Spent (hold, _)) ->
      Error
        (Last_leg_end.timed_out walk until
           ~elapsed_ms:(Last_leg_hold.elapsed_ms hold))

let walk_to_event steps ~walk_only ~stop_on_battle walk move ~until
    ~earliest_end_ms =
  if ends_before_walking steps walk move ~until ~earliest_end_ms then Ok ()
  else
    walk_last_leg_to_event steps ~walk_only ~stop_on_battle walk move ~until
      ~earliest_end_ms

let walk_to_end steps ~walk_only ~stop_on_battle walk move ~until
    ~earliest_end_ms =
  match until with
  | Talk { after_legs } ->
      walk_into_talk steps ~walk_only ~stop_on_battle walk move ~after_legs
  | Scene | Event _ ->
      walk_to_event steps ~walk_only ~stop_on_battle walk move ~until
        ~earliest_end_ms

let battle_game_steps steps : Battle_stop.game_steps =
  {
    read_screen = steps.read_screen;
    wait = (fun ms -> steps.submit (Walk_inputs.wait ms));
  }

let walk_step steps ~walk_only ~battle_ahead walk
    (args : Plza_rules.Walk_args.t) =
  if args.move.wait_before_ms > 0 then
    steps.submit (Walk_inputs.wait args.move.wait_before_ms);
  let { submit; read_screen; log; log_detail } = steps in
  let free = Free_control_wait.screen_game_steps ~submit ~read_screen ~log in
  let* () = Free_control_wait.wait free walk in
  let face = Face_heading.screen_game_steps ~submit ~read_screen ~log_detail in
  let* () =
    Option.fold ~none:(Ok ()) ~some:(Face_heading.face face) args.heading_deg
  in
  match args.until with
  | Some until ->
      walk_to_end steps ~walk_only ~stop_on_battle:battle_ahead walk args.move
        ~until ~earliest_end_ms:args.earliest_end_ms
  | None ->
      let* () = play_legs steps ~walk_only args.move in
      Ok (log_final_screen steps walk)

(* As the fork's walk action (PokemonLZA_AutoStoryActionTable.cpp): with a
   story battle ahead, the battle HUD before the walk, or after a failed one,
   is a battle on screen. *)
let run_event steps ~walk_only ~battle_ahead walk args =
  if battle_ahead && Battle_stop.showing (battle_game_steps steps) then
    Error Battle_stop.battle_on_screen
  else
    match walk_step steps ~walk_only ~battle_ahead walk args with
    | Error _ when battle_ahead && Battle_stop.showing (battle_game_steps steps)
      ->
        Error Battle_stop.battle_on_screen
    | walked -> walked
