(* Fault files read back: a real one (FRLG 12.03, extra fields left alone),
   an overrun with its fields left to their defaults, a person standing, and
   the errors for an unknown kind and a missing field. The C++ reader
   (Pokemon_LegReplay.cpp) has no tests of its own; these pin its rules. *)

open Grid_geometry
open Grid_trace

let fade_name = function
  | Console_failure.Unseen -> "unseen"
  | Black -> "black"
  | Dim -> "dim"
  | White -> "white"

let overrun_text (o : Console_failure.overrun) =
  Printf.sprintf "%s %s %d %s %s" o.step
    (Direction.name o.direction)
    o.tiles (fade_name o.fade)
    (Option.value o.far_pose_of ~default:"-")

let fault_text fault =
  let kind = Console_failure.fault_kind_name fault in
  let detail =
    match fault with
    | Console_failure.Fade_missed index | Banner_missed index ->
        string_of_int index
    | Moved_further o | Hold_through_warp o | Scene_ends_further o ->
        overrun_text o
    | Moved_less { step; index; tiles } ->
        Printf.sprintf "%s %d %d" step index tiles
    | Person_stands { name; tile } ->
        Printf.sprintf "%s %s" name (Tile_pos.to_string tile)
  in
  kind ^ " " ^ detail

let start_text = function
  | None -> "start -"
  | Some (tile, facing) ->
      Printf.sprintf "start %s facing %s"
        (Route_tile.to_string tile)
        (Direction.name facing)

let failure_text (f : Console_failure.t) =
  String.concat "\n"
    ([ f.name ^ " " ^ f.checkpoint; start_text f.start ]
    @ List.map fault_text f.faults
    @ [ "failed " ^ f.failed_step ^ ": " ^ f.failed_error; "frame " ^ f.frame ]
    @ List.map (fun line -> "evidence " ^ line) f.evidence)

let parsed name text =
  match Console_failure.parse ~name text with
  | Ok failure -> failure_text failure
  | Error why -> "error: " ^ why

let pallet_shore =
  {|{
  "about": "lab-B 2026-11-12 22:22, FRLG 12.03 pallet_shore: both holds east moved 0 tiles.",
  "checkpoint": "12.03",
  "start": {"map": "PalletTown", "tile": [6, 8], "facing": "south"},
  "walk": {"event": "pallet_shore", "legs": [["south", 2], ["east", 4]]},
  "faults": [
    {"kind": "moved_less", "step": "pallet_shore", "index": 2, "tiles": 4},
    {"kind": "moved_less", "step": "pallet_shore", "index": 3, "tiles": 6}
  ],
  "failed": {"step": "pallet_shore", "error": "none: the walk ended 'arrived at PalletTown (8, 14)'"},
  "frame": "20261112-222235-pallet-shore-east-unmoved.png",
  "evidence": [
    "[Route] pallet_shore: east 4 (open): ended at PalletTown (10, 10) (walked)."
  ]
}|}

let warp_defaults =
  {|{"checkpoint": "01.02",
  "faults": [{"kind": "hold_through_warp", "step": "past_curtis", "direction": "east"},
             {"kind": "moved_further", "step": "to_door", "direction": "north",
              "tiles": 2, "fade": "dim", "far_pose_of": "into_oreburgh"},
             {"kind": "fade_missed", "index": 0}],
  "failed": {"step": "into_oreburgh", "error": "no_banner"},
  "frame": "2026-11-11.png"}|}

let person =
  {|{"checkpoint": "14.01",
  "faults": [{"kind": "person_stands", "name": "scientist", "tile": [4, 7]}],
  "failed": {"step": "quiz_2", "error": "blocked"}, "frame": "f.png"}|}

let unknown_kind =
  {|{"checkpoint": "01.02", "faults": [{"kind": "fell_over"}],
  "failed": {"step": "s", "error": "e"}, "frame": "f.png"}|}

let no_failed = {|{"checkpoint": "01.02", "faults": [], "frame": "f.png"}|}
let case name input expectation = { Table_test.name; input; expectation }

let cases =
  [
    case "a console run's file, unknown fields left alone"
      (fun () -> parsed "12.03-pallet" pallet_shore)
      "12.03-pallet 12.03\n\
       start PalletTown (6, 8) facing south\n\
       moved_less pallet_shore 2 4\n\
       moved_less pallet_shore 3 6\n\
       failed pallet_shore: none: the walk ended 'arrived at PalletTown (8, 14)'\n\
       frame 20261112-222235-pallet-shore-east-unmoved.png\n\
       evidence [Route] pallet_shore: east 4 (open): ended at PalletTown (10, \
       10) (walked).";
    case "an overrun's left-out fields take their defaults"
      (fun () -> parsed "warp" warp_defaults)
      "warp 01.02\n\
       start -\n\
       hold_through_warp past_curtis east 1 unseen -\n\
       moved_further to_door north 2 dim into_oreburgh\n\
       fade_missed 0\n\
       failed into_oreburgh: no_banner\n\
       frame 2026-11-11.png";
    case "a person standing on a tile"
      (fun () -> parsed "person" person)
      "person 14.01\n\
       start -\n\
       person_stands scientist (4, 7)\n\
       failed quiz_2: blocked\n\
       frame f.png";
    case "an unknown fault kind"
      (fun () -> parsed "bad" unknown_kind)
      "error: console failure bad: faults[0].kind: unknown fault kind \
       \"fell_over\".";
    case "no failed step"
      (fun () -> parsed "bad" no_failed)
      "error: console failure bad: failed is missing.";
  ]

let () = Table_test.run "ConsoleFailure" cases
