module Failure = Engine_run.Failure

let slice_ms = 250
let gone_ms = 400
let runs = 2

(* B held with the stick for the whole slice, as run_towards_gate_with_A_button
   holds it. *)
let run_whole = { Switch_home.Stick_tilt.button = Wire.B; speedup = 1.0 }
let ( let* ) = Result.bind

let slice (steps : Walk.game_steps) =
  match
    Switch_home.Stick_tilt.tilt ~run:run_whole ~degrees:0. ~duration_ms:slice_ms
      ~release_ms:0 ()
  with
  | Ok input -> Ok (steps.submit input)
  | Error e -> Error (Failure.cause ~repeats:true "walk_stick" e)

type ended = Prompt | Day_night | Out_of_time

(* Slices until the A prompt shows, the party bar has been gone [gone_ms] (a
   day/night change), or [timeout_ms] of slices have run. [gone_since]: the
   first read of the bar's absence in a row. *)
let rec run_slices steps ~timeout_ms ~ran ~gone_since =
  if ran >= timeout_ms then Ok Out_of_time
  else
    let* () = slice steps in
    let (look : Walk_screen.t) = steps.read_screen () in
    let gone_since =
      if look.player_can_move then None
      else Some (Option.value gone_since ~default:look.at_ms)
    in
    match gone_since with
    | _ when look.interact_prompt -> Ok Prompt
    | Some since when look.at_ms -. since >= float_of_int gone_ms ->
        Ok Day_night
    | _ -> run_slices steps ~timeout_ms ~ran:(ran + slice_ms) ~gone_since

let not_reached timeout_ms =
  Failure.cause "gate_not_reached"
    (Printf.sprintf "no gate A prompt in %d ms of running" timeout_ms)

let rec attempt steps ~timeout_ms n =
  let* ended = run_slices steps ~timeout_ms ~ran:0 ~gone_since:None in
  match ended with
  | Prompt ->
      steps.Walk.log "[PLZA] run_to_gate: the gate's A prompt: reached the gate";
      Ok ()
  | Day_night when n + 1 < runs ->
      steps.log "[PLZA] run_to_gate: a day/night change while running";
      let* () =
        Free_control_wait.wait
          (Walk.free_control_game_steps steps)
          "run_to_gate"
      in
      attempt steps ~timeout_ms (n + 1)
  | Day_night | Out_of_time -> Error (not_reached timeout_ms)

let run steps ~timeout_ms = attempt steps ~timeout_ms 0
