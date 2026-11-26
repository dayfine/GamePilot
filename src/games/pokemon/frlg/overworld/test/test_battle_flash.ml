(* Battle_flash on the fade probe of real mGBA frames, one per game frame from
   a pacing step's first press (fixtures/*.fade.jsonl, cut from run wire logs):
   the first sign it sees, and on which frame. A turn and step take 36 frames
   to walk, so a flash before then is the turn's. *)

open Frlg_overworld

let case name input expectation = { Table_test.name; input; expectation }
let frame_ms = 1000. /. 59.7275

let frames file =
  List.mapi
    (fun i (_, probes) ->
      { Wire.seq = i; t_ms = float_of_int i *. frame_ms; probes })
    (Wire.read_image_probes file)

let sign_name : Battle_flash.sign -> string = function
  | Flash -> "flash"
  | Going_black -> "going black"

let first_sign file () =
  let watcher = Battle_flash.create () in
  let signs =
    List.filter_map
      (fun (m : Effects.measurements) ->
        Option.map (fun s -> (m.seq, s)) (Battle_flash.sign watcher m))
      (frames file)
  in
  match signs with
  | [] -> "none"
  | (seq, sign) :: _ -> Printf.sprintf "%s at frame %d" (sign_name sign) seq

let cases =
  [
    (* 320 to 266 and back, twice: the fork's fifth never saw it. *)
    case "Viridian Forest: a walk's faint flash"
      (first_sign "fixtures/viridian_forest_walk_flash.fade.jsonl")
      "flash at frame 54";
    case "Viridian Forest: four steps with no battle"
      (first_sign "fixtures/viridian_forest_quiet_steps.fade.jsonl")
      "none";
    case "Route 3: a walk's flash, after the walk"
      (first_sign "fixtures/route3_walk_flash.fade.jsonl")
      "flash at frame 51";
    case "Route 3: a turn's flash, before the walk could end"
      (first_sign "fixtures/route3_turn_flash.fade.jsonl")
      "flash at frame 23";
  ]

let () = Table_test.run "battle flash" cases
