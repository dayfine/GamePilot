module Failure = Engine_run.Failure

type game_steps = {
  submit : Wire.command -> unit;
  read_screen : unit -> Story_look.t;
  log : string -> unit;
  log_detail : string -> unit;
}

type outcome = (unit, Failure.cause) result

let press_hold_ms = 160
let press_release_ms = 240
let ms_per_second = 1000.0
let seconds ms = ms /. ms_per_second

let press steps button ~hold_ms ~release_ms =
  steps.submit (Wire.press ~hold_ms ~cooldown_ms:release_ms [ button ])

let wait steps wait_ms = steps.submit (Wire.Wait { wait_ms })

let walk_game_steps steps : Plza_walk.Walk.game_steps =
  {
    submit = steps.submit;
    read_screen = (fun () -> Story_look.to_walk_screen (steps.read_screen ()));
    log = steps.log;
    log_detail = steps.log_detail;
  }

let game_not_running =
  Failure.cause ~repeats:true "game_not_running"
    Switch_home.Screen_poll.not_running

type waited =
  | Matched of { look : Story_look.t; looks : int; elapsed_ms : float }
  | Timed_out
  | Home_menu

type rule = {
  poll_ms : int;
  timeout_ms : int;
  confirm_looks : int;
  confirm_hold_ms : int;
}

let rule ?(confirm_looks = 1) ?(confirm_hold_ms = 0) ~poll_ms ~timeout_ms () =
  { poll_ms; timeout_ms; confirm_looks; confirm_hold_ms }

(* The reads in a row the check has held on, and the first one's time. *)
type run = { count : int; since : float }

let confirmed rule run (look : Story_look.t) =
  run.count >= rule.confirm_looks
  && look.at_ms -. run.since >= float_of_int rule.confirm_hold_ms

let poll_until steps rule holds act =
  let max_looks = (rule.timeout_ms / max 1 rule.poll_ms) + 1 in
  let rec go ~start ~looks run =
    let look = steps.read_screen () in
    let start = Option.value start ~default:look.at_ms in
    let run =
      if holds look then
        {
          count = run.count + 1;
          since = (if run.count = 0 then look.at_ms else run.since);
        }
      else { count = 0; since = look.at_ms }
    in
    if look.home_menu then Home_menu
    else if run.count > 0 && confirmed rule run look then
      Matched { look; looks = run.count; elapsed_ms = look.at_ms -. start }
    else if
      look.at_ms -. start >= float_of_int rule.timeout_ms || looks >= max_looks
    then Timed_out
    else (
      act look;
      go ~start:(Some start) ~looks:(looks + 1) run)
  in
  go ~start:None ~looks:1 { count = 0; since = 0.0 }

let wait_for steps rule holds =
  poll_until steps rule holds (fun _ -> wait steps rule.poll_ms)
