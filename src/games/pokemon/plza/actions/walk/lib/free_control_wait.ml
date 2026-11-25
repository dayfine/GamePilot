open Engine_run

type game_steps = {
  read_screen : unit -> Walk_screen.t;
  wait : int -> unit;
  log : string -> unit;
}

(* The timeout: only a stuck game gets this far; free control confirms in
   about 0.5 s (two reads). *)
let free_control_wait_ms = 30000
let free_control_read_ms = 250

(* Nothing busy this long, with no sign of control, is control where no sign
   shows. *)
let quiet_is_control_ms = 10000

(* Reads of free control in a row that confirm it. *)
let control_reads = 2

(* An A prompt shows only in the overworld, so it is control where no party
   bar shows (01.03). Held a second, so a prompt left up under a late fade
   after A at a door is not taken. *)
let prompt_is_control_ms = 1000

(* What the wait has seen so far. *)
type watch = {
  mutable last_busy : string;
  mutable control_streak : int;
  mutable quiet_since : int option;
  mutable prompt_since : int option;
  mutable poll_reads : int;
}

(* Whether nothing has been busy for the quiet time, on the reads' own clock,
   [poll_reads] polls apart. *)
let quiet_ready watch ~quiet poll_time =
  if not quiet then (
    watch.quiet_since <- None;
    false)
  else
    let since = Option.value ~default:poll_time watch.quiet_since in
    watch.quiet_since <- Some since;
    poll_time - since >= quiet_is_control_ms

(* Whether an A prompt with nothing busy has held a second. *)
let prompt_ready watch ~prompt poll_time =
  if not prompt then (
    watch.prompt_since <- None;
    false)
  else
    let since = Option.value ~default:poll_time watch.prompt_since in
    watch.prompt_since <- Some since;
    poll_time - since >= prompt_is_control_ms

(* Whether free control has held on [control_reads] reads in a row. *)
let streak watch matched =
  watch.control_streak <- (if matched then watch.control_streak + 1 else 0);
  matched && watch.control_streak >= control_reads

(* The quiet time is updated before the streak, as in the C++. *)
let free_control_shows steps walk watch screen =
  let poll_time = watch.poll_reads * free_control_read_ms in
  watch.poll_reads <- watch.poll_reads + 1;
  let busy = Walk_screen.busy_with screen in
  Option.iter (fun b -> watch.last_busy <- b) busy;
  let quiet = quiet_ready watch ~quiet:(busy = None) poll_time in
  if streak watch (Walk_screen.player_free screen) then true
  else if
    prompt_ready watch ~prompt:(busy = None && screen.interact_prompt) poll_time
  then (
    steps.log
      (Printf.sprintf
         "[PLZA] %s: the A prompt held %d ms with nothing busy: control." walk
         prompt_is_control_ms);
    true)
  else if quiet then (
    steps.log
      (Printf.sprintf
         "[PLZA] %s: nothing busy for %d ms and no sign of control; taken as \
          control."
         walk quiet_is_control_ms);
    true)
  else false

let not_free walk last_busy =
  Failure.cause "walk_not_free"
    (Printf.sprintf "%s: no free control within %d ms, last on %s" walk
       free_control_wait_ms last_busy)

let new_watch () =
  {
    last_busy = "nothing";
    control_streak = 0;
    quiet_since = None;
    prompt_since = None;
    poll_reads = 0;
  }

let wait steps walk =
  let watch = new_watch () in
  match
    Switch_home.Screen_poll.until
      { read_screen = steps.read_screen; wait = steps.wait }
      ~at_ms:(fun (s : Walk_screen.t) -> s.at_ms)
      ~home_menu:(fun (s : Walk_screen.t) -> s.home_menu)
      ~poll_ms:free_control_read_ms ~timeout_ms:free_control_wait_ms
      (free_control_shows steps walk watch)
  with
  | Home_menu ->
      Error
        (Failure.cause ~repeats:true "game_not_running"
           Switch_home.Screen_poll.not_running)
  | Holds _ -> Ok ()
  | Timed_out _ -> Error (not_free walk watch.last_busy)
