module Failure = Engine_run.Failure

type game_steps = {
  submit : Wire.command -> unit;
  read_screen : unit -> Walk_screen.t;
  log : string -> unit;
  log_detail : string -> unit;
}

type at_prompt = {
  until : Walk_screen.t -> bool;
  until_looks : int;
  retries : int;
  retry_gap_ms : int;
  release_ms : int;
  name : string;
}

let poll_ms = 250
let a_hold_ms = 160
let steady_gap_ms = 300

let walk_talk =
  {
    until = (fun (l : Walk_screen.t) -> l.scene_under_way);
    until_looks = 2;
    retries = 3;
    retry_gap_ms = 1000;
    release_ms = 240;
    name = "walk";
  }

(* The prompt taken (PokemonLZA_AutoStoryScreenPredicates.h): a fade or a
   text or choice box. A late fade starts 1.8 s
   after the A. *)
let through_prompt =
  {
    until =
      (fun (l : Walk_screen.t) -> l.fade_black || l.fade_white || l.dialog_box);
    until_looks = 1;
    retries = 3;
    retry_gap_ms = 3000;
    release_ms = 400;
    name = "press_through_prompt";
  }

type ended =
  | Taken of Walk_screen.t
  | Prompt_stays of { presses : int; since_ms : int }
  | Nothing

let press_a steps at =
  steps.submit
    (Walk_inputs.button Wire.A ~hold_ms:a_hold_ms ~release_ms:at.release_ms)

let wait steps ms = steps.submit (Walk_inputs.wait ms)

let again name since presses =
  Printf.sprintf
    "[PLZA] %s: the A prompt still up %d ms after A %d with nothing open; A \
     again"
    name since presses

(* After the retry gap: nothing started, the prompt gone or still up. *)
let rec after_gap steps at ~presses ~since ~looks (look : Walk_screen.t) =
  if not (looks = 0 && look.interact_prompt) then Nothing
  else if presses >= at.retries then Prompt_stays { presses; since_ms = since }
  else (
    steps.log (again at.name since presses);
    press_a steps at;
    watch steps at ~presses:(presses + 1) ~since:0 ~looks)

and watch steps at ~presses ~since ~looks =
  let look = steps.read_screen () in
  let looks = if at.until look then looks + 1 else 0 in
  if looks >= at.until_looks then Taken look
  else poll_on steps at ~presses ~since:(since + poll_ms) ~looks look

and poll_on steps at ~presses ~since ~looks look =
  wait steps poll_ms;
  if since < at.retry_gap_ms then watch steps at ~presses ~since ~looks
  else after_gap steps at ~presses ~since ~looks look

let a_at_prompt steps at =
  press_a steps at;
  watch steps at ~presses:1 ~since:0 ~looks:0

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
  match a_at_prompt steps { walk_talk with name = walk } with
  | Taken look -> started steps walk ~held_ms look
  | Prompt_stays { presses; _ } -> Some (Error (no_scene walk presses))
  | Nothing ->
      steps.log
        (Printf.sprintf
           "[PLZA] %s: the A prompt went with nothing started after A: on." walk);
      None

let still_up since_ms presses =
  Printf.sprintf
    "[PLZA] press_through_prompt: the prompt is still up %d ms after A %d"
    since_ms presses

let press_through steps =
  match a_at_prompt steps through_prompt with
  | Prompt_stays { presses; since_ms } -> steps.log (still_up since_ms presses)
  | Taken _ | Nothing -> ()

let steady steps =
  wait steps steady_gap_ms;
  (steps.read_screen ()).interact_prompt

(* Free control with no A prompt: nothing for A to take. *)
let no_prompt (l : Walk_screen.t) =
  (l.player_can_move || l.controls_hint)
  && (not l.dialog_box) && not l.interact_prompt

let missing steps =
  no_prompt (steps.read_screen ())
  &&
  (wait steps steady_gap_ms;
   no_prompt (steps.read_screen ()))
