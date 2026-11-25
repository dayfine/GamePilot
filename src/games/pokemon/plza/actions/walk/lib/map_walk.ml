open Map_leg

let ( let* ) = Result.bind
let button_hold_ms = 100
let map_open_ms = 1500
let map_close_ms = 1000
let pin_looks = 8
let pin_look_gap_ms = 250
let release_ms = 300
let gate_runs = 3

let press (steps : Walk.game_steps) b ~release_ms =
  steps.submit (Inputs.button b ~hold_ms:button_hold_ms ~release_ms)

let wait (steps : Walk.game_steps) ms = steps.submit (Inputs.wait ms)
let pin_text = function Some p -> Wild_zone_one.point_text p | None -> "none"

let read_pin (steps : Walk.game_steps) =
  press steps Plus ~release_ms:map_open_ms;
  (* As the C++ loop: 250 ms after every miss, the last one too. *)
  let rec look n =
    match (steps.read_screen ()).map_pin with
    | Some p -> Some p
    | None ->
        wait steps pin_look_gap_ms;
        if n + 1 >= pin_looks then None else look (n + 1)
  in
  let pin = look 0 in
  press steps B ~release_ms:map_close_ms;
  steps.log ("[PLZA] map pin: " ^ pin_text pin);
  pin

let face (steps : Walk.game_steps) heading =
  let { Walk.submit; read_screen; log_detail; _ } = steps in
  Face_heading.face
    (Face_heading.screen_game_steps ~submit ~read_screen ~log_detail)
    heading

let stick (steps : Walk.game_steps) pace ~hold_ms =
  match
    Inputs.tilt ~walk_only:false pace ~degrees:0. ~duration_ms:hold_ms
      ~release_ms
  with
  | Ok c -> Ok (steps.submit c)
  | Error e -> Error (Engine_run.Failure.cause ~repeats:true "walk_stick" e)

let waypoint_text w = w.name ^ " " ^ Wild_zone_one.point_text w.pin

let off_target w pin =
  Engine_run.Failure.cause "leg_off_target"
    (Printf.sprintf "wanted %s, at %s (%s)"
       (Wild_zone_one.point_text w.pin)
       (pin_text pin) w.name)

let pin_lost w =
  Engine_run.Failure.cause "map_pin_not_read" ("on the way to " ^ w.name)

let arrived (steps : Walk.game_steps) w pin =
  steps.log
    (Printf.sprintf "[PLZA] map leg to %s: arrived at %s" (waypoint_text w)
       (pin_text pin));
  Ok pin

let leg_over steps w pin = function
  | Arrived -> arrived steps w pin
  | Off_target -> Error (off_target w pin)
  | Read_again | Walk _ | Pin_not_read -> Error (pin_lost w)

let walk_move (steps : Walk.game_steps) w pin ~heading ~hold_ms ~correction =
  steps.log
    (Printf.sprintf "[PLZA] map leg to %s: %s from %s, heading %.0f, hold %d ms"
       (waypoint_text w)
       (if correction = 0 then "walk"
        else Printf.sprintf "correction %d" correction)
       (pin_text pin) heading hold_ms);
  let* () = face steps heading in
  stick steps Inputs.Walk ~hold_ms

(* The map's cursor can snap onto a badge next to the player, its ring over
   the player's arrow (the zone's "1" at the 60 spot). *)
let short_step (steps : Walk.game_steps) =
  steps.log "[PLZA] map pin not read: a short step, then the map again";
  stick steps Inputs.Walk ~hold_ms:release_ms

let rec walk_leg steps w leg pin =
  match Map_leg.next leg pin with
  | leg, Read_again ->
      let* () = short_step steps in
      walk_leg steps w leg (read_pin steps)
  | leg, Walk { heading; hold_ms; correction } ->
      let* () = walk_move steps w pin ~heading ~hold_ms ~correction in
      walk_leg steps w leg (read_pin steps)
  | _, move -> leg_over steps w pin move

let walk_legs steps waypoints =
  let* (_ : point option) =
    List.fold_left
      (fun pin w ->
        let* pin = pin in
        walk_leg steps w (Map_leg.start w.pin ~stop_radius:w.stop_radius) pin)
      (Ok (read_pin steps))
      waypoints
  in
  Ok ()

(* From [from] to [to_] by dead reckoning, B held. *)
let run_exit_leg (steps : Walk.game_steps) from to_ =
  let run heading hold_ms =
    steps.log
      (Printf.sprintf
         "[PLZA] run_out_of_zone_1: to %s first, heading %.0f, hold %d ms"
         (Wild_zone_one.point_text to_)
         heading hold_ms);
    let* () = face steps heading in
    stick steps Inputs.Run ~hold_ms
  in
  match Map_leg.next (Map_leg.start to_ ~stop_radius:0.) (Some from) with
  | _, Walk { heading; hold_ms; _ } -> run heading hold_ms
  | _ -> Ok ()

type exit_run = Reached | Missed of Engine_run.Failure.cause

let rec run_legs steps ~timeout_ms from = function
  | [] -> Ok Reached
  | [ gate ] -> (
      let* () = face steps (bearing from gate) in
      match Gate_run.run steps ~timeout_ms with
      | Ok () -> Ok Reached
      | Error c -> Ok (Missed c))
  | next :: rest ->
      let* () = run_exit_leg steps from next in
      run_legs steps ~timeout_ms next rest

let no_pin =
  Engine_run.Failure.cause "map_pin_not_read"
    "no map pin before the run to the far gate"

let log_again (steps : Walk.game_steps) runs pin =
  if runs > 0 then
    steps.log
      (Printf.sprintf
         "[PLZA] run_out_of_zone_1: no prompt on run %d, again from %s" runs
         (Wild_zone_one.point_text pin))

let rec run_out steps ~timeout_ms runs =
  let from pin =
    log_again steps runs pin;
    run_legs steps ~timeout_ms pin (Wild_zone_one.exit_legs pin)
  in
  let* run = Option.fold ~none:(Error no_pin) ~some:from (read_pin steps) in
  match run with
  | Reached -> Ok ()
  | Missed c when runs + 1 >= gate_runs -> Error c
  | Missed _ -> run_out steps ~timeout_ms (runs + 1)

let run_out_of_zone_one steps ~timeout_ms = run_out steps ~timeout_ms 0

let check_out_of_zone_one (steps : Walk.game_steps) =
  match Wild_zone_one.check_out (fun () -> read_pin steps) with
  | Ok reads ->
      steps.log ("[PLZA] out of Wild Zone 1: the map pin reads " ^ reads);
      Ok ()
  | Error c ->
      steps.log ("[PLZA] " ^ c.detail);
      Error c
