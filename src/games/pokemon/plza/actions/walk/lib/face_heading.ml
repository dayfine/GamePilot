type game_steps = {
  submit : Wire.command -> unit;
  read_arrow : unit -> float option;
  log_detail : string -> unit;
}

let screen_game_steps ~submit ~read_screen ~log_detail =
  {
    submit;
    read_arrow = (fun () -> (read_screen () : Screen.t).minimap_arrow);
    log_detail;
  }

let ( let* ) = Result.bind
let tolerance = 4.
let max_turns = 4
let turn_reads = 10
let turn_read_gap_ms = 100
let arrow_wait_ms = 40_000
let arrow_poll_ms = 100
let half_turn = 180.
let full_turn = 360.

let turn_to now heading =
  let t = Float.rem (heading -. now) full_turn in
  if t > half_turn then t -. full_turn
  else if t <= -.half_turn then t +. full_turn
  else t

let wait (steps : game_steps) ms = steps.submit (Inputs.wait ms)

let no_arrow =
  Engine_run.Failure.cause "arrow_unread" "no minimap arrow within 40 s"

(* The arrow, waited for up to 40 s. *)
let arrow (steps : game_steps) =
  let rec look waited =
    match steps.read_arrow () with
    | Some a -> Ok a
    | None when waited >= arrow_wait_ms -> Error no_arrow
    | None ->
        wait steps arrow_poll_ms;
        look (waited + arrow_poll_ms)
  in
  look 0

(* The last read when the arrow never moves half the turn: it did not take. *)
let read_after_turn steps before turn =
  let rec go reads now =
    if
      reads >= turn_reads
      || Float.abs (turn_to before now) >= Float.abs turn /. 2.
    then Ok now
    else (
      wait steps turn_read_gap_ms;
      let* now = arrow steps in
      go (reads + 1) now)
  in
  let* now = arrow steps in
  go 1 now

let tap_hold_ms = 100
let tap_release_ms = 150
let turn_ms = 150
let turn_release_ms = 100

let tap_l (steps : game_steps) =
  steps.submit (Inputs.button L ~hold_ms:tap_hold_ms ~release_ms:tap_release_ms)

(* The tap the story was recorded with. *)
let story_turn (steps : game_steps) degrees =
  tap_l steps;
  match
    Inputs.tilt ~walk_only:true Walk ~degrees ~duration_ms:turn_ms
      ~release_ms:turn_release_ms
  with
  | Ok c -> Ok (steps.submit c)
  | Error why -> Error (Engine_run.Failure.cause "bad_tilt" why)

let missed heading =
  Engine_run.Failure.cause "heading_missed"
    (Printf.sprintf "not facing %.0f deg after %d turns" heading max_turns)

let face (steps : game_steps) heading =
  let rec go turns ~gain ~last now =
    let turn = turn_to now heading in
    steps.log_detail
      (Printf.sprintf
         "[PLZA] face_heading: the arrow reads %.1f deg, %.0f wanted: %.1f off"
         now heading turn);
    if Float.abs turn <= tolerance then Ok (tap_l steps)
    else if turns >= max_turns then Error (missed heading)
    else
      let gain = if last *. turn < 0. then gain /. 2. else gain in
      let asked = turn *. gain in
      let* () = story_turn steps asked in
      let* now' = read_after_turn steps now asked in
      go (turns + 1) ~gain ~last:turn now'
  in
  let* now = arrow steps in
  go 0 ~gain:1. ~last:0. now
