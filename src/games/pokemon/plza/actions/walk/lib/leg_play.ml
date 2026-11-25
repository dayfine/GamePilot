open Plza_rules.Walk_args
module Failure = Engine_run.Failure

type game_steps = {
  submit : Wire.command -> unit;
  read_screen : unit -> Screen.t;
  log : string -> unit;
  log_detail : string -> unit;
}

let ( let* ) = Result.bind

(* The L tap that recentres the camera, and the tilt the story was recorded
   with; short releases run legs back to back. *)
let recenter_hold_ms = 100
let recenter_release_ms = 150
let face_tilt_ms = 150
let face_release_ms = 100

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
