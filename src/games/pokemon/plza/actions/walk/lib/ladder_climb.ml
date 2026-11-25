module Failure = Engine_run.Failure

type game_steps = Talk_prompt.game_steps

let climb_ms = 6500
let release_ms = 500
let nudge_ms = 150
let side_ms = 250
let side_release_ms = 100
let back_ms = 120

(* Sideways from the facing: 5 left, then 11 right, back past the start. *)
let side_degrees = 90.
let lefts = 5
let rights = 11

let sidesteps =
  List.init lefts (fun _ -> -.side_degrees)
  @ List.init rights (fun _ -> side_degrees)

let tilt (steps : game_steps) ~degrees ~duration_ms ~release_ms =
  match Inputs.tilt ~walk_only:true Walk ~degrees ~duration_ms ~release_ms with
  | Ok input -> Ok (steps.submit input)
  | Error e -> Error (Failure.cause ~repeats:true "walk_stick" e)

let ( let* ) = Result.bind

(* The steps taken until the prompt showed; [None] when it never did. *)
let rec step_along (steps : game_steps) taken = function
  | _ when (steps.read_screen ()).interact_prompt -> Ok (Some taken)
  | [] -> Ok None
  | side :: rest ->
      let* () =
        tilt steps ~degrees:side ~duration_ms:side_ms
          ~release_ms:side_release_ms
      in
      let* () = tilt steps ~degrees:0. ~duration_ms:back_ms ~release_ms in
      step_along steps (taken + 1) rest

let not_found =
  Failure.cause "ladder_not_found" "no Climb Up prompt stepping along the wall"

let climb (steps : game_steps) taken =
  steps.log
    (Printf.sprintf
       "[PLZA] climb_ladder: Climb Up after %d steps along the wall" taken);
  Talk_prompt.press_through steps;
  tilt steps ~degrees:0. ~duration_ms:climb_ms ~release_ms

let run (steps : game_steps) =
  let* () = tilt steps ~degrees:0. ~duration_ms:nudge_ms ~release_ms in
  let* found = step_along steps 0 sidesteps in
  match found with Some taken -> climb steps taken | None -> Error not_found
