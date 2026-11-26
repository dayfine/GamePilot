(* The map pin reader (PokemonLZA_MapPinReader.cpp) on the fork's test frames
   (PokemonLZA_Detectors_Tests.cpp): its drawn maps and two
   console maps of Wild Zone 1. The fork passes a pin within 2 of the
   expected. *)

open Plza_readers

let text = function
  | Some (p : Map_pin.point) -> Printf.sprintf "(%.1f, %.1f)" p.x p.y
  | None -> "none"

let case name frame expectation : Table_test.case =
  {
    name;
    input = (fun () -> text (Map_pin.read (Fixture_frames.frame frame)));
    expectation;
  }

let cases =
  [
    case "the arrow with the camera's cone beside it"
      "synthetic/map-arrow-and-cone" "(370.0, 230.0)";
    case "the cone only" "synthetic/map-cone-only" "none";
    case "the arrow's blue outside the zone's window"
      "synthetic/map-arrow-outside-window" "none";
    case "a speck of the arrow's blue" "synthetic/map-arrow-speck" "none";
    (* The fork's (358.9, 227.3). *)
    case "console: stuck at the zone's north fence"
      "map-pin/zone1-at-north-fence" "(358.3, 228.1)";
    (* The fork's (415.4, 230.4). *)
    case
      "console: the patrol's stop 10, the arrow partly under the zone's badge"
      "map-pin/zone1-stop-10-under-badge" "(414.4, 230.4)";
    (* 21-fourth-species's and 23-out-of-wild-zone-1's map reads (640x360 run frames scaled up, console
       B, 2026-11-25), against the pin the run logged. *)
    case "21-fourth-species at Taunie's rocks (run: 476, 223)"
      "map-pin/en-0308-zone1-rocks-005-360p" "(475.0, 223.8)";
    case "21-fourth-species at the 100 spot (run: 441, 229)"
      "map-pin/en-0308-zone1-spot-100-033-360p" "(440.6, 228.8)";
    case "23-out-of-wild-zone-1 at the 80 spot (run: 403, 233)"
      "map-pin/en-0308b-zone1-spot-80-005-360p" "(405.0, 233.8)";
    case
      "23-out-of-wild-zone-1 out of the zone, the map opening (run: 401, 227)"
      "map-pin/en-0308b-out-of-zone1-024-360p" "(401.9, 225.6)";
    case "no map: the 03.03 start" "minimap/es-0303-start" "none";
  ]

let is_map name =
  String.starts_with ~prefix:"map-pin/" name
  || String.starts_with ~prefix:"synthetic/map-" name

(* The 640x360 run frames scaled up lose the pin's blue at brightness 0.9,
   and the out-of-zone one reads 2.5 off at 1.1: the full-size maps keep
   the shift check. *)
let scaled_up name = String.ends_with ~suffix:"-360p" name

(* A shifted map reads within 2 of the frame, or none where it does. Only
   maps: the pin is read with the map open, and other screens have the
   arrow's blue in the window (text boxes, a battle). *)
let shifted_cases =
  List.filter
    (fun (path, _) ->
      let name = snd (Fixture_frames.shift_and_frame path) in
      is_map name && not (scaled_up name))
    Fixture_frames.shifted
  |> List.map (fun (path, probes) : Table_test.case ->
         let shift, name = Fixture_frames.shift_and_frame path in
         {
           name = Printf.sprintf "%s, %s: within 2" name shift;
           input =
             (fun () ->
               match
                 ( Map_pin.read (Fixture_frames.measurements probes),
                   Map_pin.read (Fixture_frames.frame name) )
               with
               | Some a, Some b
                 when Float.abs (a.x -. b.x) <= 2.
                      && Float.abs (a.y -. b.y) <= 2. ->
                   "ok"
               | None, None -> "ok"
               | a, _ -> text a);
           expectation = "ok";
         })

let () = Table_test.run "map_pin" (cases @ shifted_cases)
