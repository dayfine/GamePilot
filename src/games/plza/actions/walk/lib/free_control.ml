open Engine_run

type game_steps = {
  look : unit -> Walk_look.t;
  wait : int -> unit;
  log : string -> unit;
}

let free_control_wait_ms = 30000
let free_control_look_ms = 250
let quiet_is_control_ms = 10000

(* Looks of free control in a row that confirm it. *)
let control_looks = 2

(* FreeControlWatch, and the wait's looks and start. *)
type watch = {
  mutable last_busy : string;
  mutable control_streak : int;
  mutable quiet_since : int option;
  mutable poll_looks : int;
}

(* The C++'s game_not_running_failure. *)
let game_not_running =
  Failure.cause ~repeats:true "game_not_running"
    "the game is not running: the Switch HOME menu is showing"

(* HoldTimer.update on the looks' own clock, [poll_looks] looks apart. *)
let quiet_ready watch ~quiet poll_time =
  if not quiet then (
    watch.quiet_since <- None;
    false)
  else
    let since = Option.value ~default:poll_time watch.quiet_since in
    watch.quiet_since <- Some since;
    poll_time - since >= quiet_is_control_ms

(* ConfirmStreak.update. *)
let streak watch matched =
  watch.control_streak <- (if matched then watch.control_streak + 1 else 0);
  matched && watch.control_streak >= control_looks

let check_free_control steps walk look watch =
  let poll_time = watch.poll_looks * free_control_look_ms in
  watch.poll_looks <- watch.poll_looks + 1;
  let busy = Walk_look.not_free_control look in
  Option.iter (fun b -> watch.last_busy <- b) busy;
  let quiet = quiet_ready watch ~quiet:(busy = None) poll_time in
  if streak watch (Walk_look.overworld_free look) then true
  else if quiet then (
    steps.log
      (Printf.sprintf
         "[PLZA] %s: nothing busy for %d ms and no sign of control; taken as \
          control."
         walk quiet_is_control_ms);
    true)
  else false

let max_looks = (free_control_wait_ms / free_control_look_ms) + 1

(* Pokemon::poll_until: the HOME menu fails, a match ends the wait, the
   timeout or the looks' count gives up, and otherwise wait a poll. *)
let rec poll steps walk watch ~start ~looks =
  let look = steps.look () in
  let looks = looks + 1 in
  let start = Option.value ~default:look.at_ms start in
  let elapsed = Float.max 0.0 (look.at_ms -. start) in
  if look.home_menu then Error game_not_running
  else if check_free_control steps walk look watch then Ok true
  else if elapsed >= float_of_int free_control_wait_ms || looks >= max_looks
  then Ok false
  else (
    steps.wait free_control_look_ms;
    poll steps walk watch ~start:(Some start) ~looks)

let not_free walk last_busy =
  Failure.cause "walk_not_free"
    (Printf.sprintf "%s: no free control within %d ms, last on %s" walk
       free_control_wait_ms last_busy)

let new_watch () =
  {
    last_busy = "nothing";
    control_streak = 0;
    quiet_since = None;
    poll_looks = 0;
  }

let check_can_walk steps walk =
  let watch = new_watch () in
  match poll steps walk watch ~start:None ~looks:0 with
  | Error failure -> Error failure
  | Ok true -> Ok ()
  | Ok false -> Error (not_free walk watch.last_busy)
