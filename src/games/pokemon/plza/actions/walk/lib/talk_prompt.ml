module Failure = Engine_run.Failure

type game_steps = {
  submit : Wire.command -> unit;
  read_screen : unit -> Walk_screen.t;
  log : string -> unit;
  log_detail : string -> unit;
}

let poll_ms = 250
let until_looks = 2
let retries = 3
let retry_gap_ms = 1000
let a_hold_ms = 160
let a_release_ms = 240
let steady_gap_ms = 300

type ended = Taken of Walk_screen.t | Prompt_stays of int | Nothing

let press_a steps =
  steps.submit
    (Walk_inputs.button Wire.A ~hold_ms:a_hold_ms ~release_ms:a_release_ms)

let wait steps ms = steps.submit (Walk_inputs.wait ms)

let again walk since presses =
  Printf.sprintf
    "[PLZA] %s: the A prompt still up %d ms after A %d with nothing open; A \
     again"
    walk since presses

(* After the retry gap: nothing started, the prompt gone or still up. *)
let rec after_gap steps walk ~presses ~looks (look : Walk_screen.t) =
  if not (looks = 0 && look.interact_prompt) then Nothing
  else if presses >= retries then Prompt_stays presses
  else (
    steps.log (again walk retry_gap_ms presses);
    press_a steps;
    watch steps walk ~presses:(presses + 1) ~since:0 ~looks)

and watch steps walk ~presses ~since ~looks =
  let look = steps.read_screen () in
  let looks = if look.scene_under_way then looks + 1 else 0 in
  if looks >= until_looks then Taken look
  else poll_on steps walk ~presses ~since:(since + poll_ms) ~looks look

and poll_on steps walk ~presses ~since ~looks look =
  wait steps poll_ms;
  if since < retry_gap_ms then watch steps walk ~presses ~since ~looks
  else after_gap steps walk ~presses ~looks look

let started steps walk ~held_ms look =
  steps.log
    (Printf.sprintf
       "[PLZA] %s: A on the A prompt after %d ms of the last leg started a \
        talk."
       walk held_ms);
  steps.log_detail
    (Printf.sprintf "[PLZA] %s: started on: %s" walk
       (Walk_screen.describe look));
  Some (Ok ())

let no_scene walk presses =
  Failure.cause "talk_no_scene"
    (Printf.sprintf
       "%s: the A prompt still up with nothing open after %d As: the game took \
        none"
       walk presses)

let talk steps walk ~held_ms =
  press_a steps;
  match watch steps walk ~presses:1 ~since:0 ~looks:0 with
  | Taken look -> started steps walk ~held_ms look
  | Prompt_stays presses -> Some (Error (no_scene walk presses))
  | Nothing ->
      steps.log
        (Printf.sprintf
           "[PLZA] %s: the A prompt went with nothing started after A: on." walk);
      None

let steady steps =
  wait steps steady_gap_ms;
  (steps.read_screen ()).interact_prompt
