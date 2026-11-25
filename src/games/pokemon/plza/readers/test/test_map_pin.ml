(* The map pin reader (PokemonLZA_MapPinReader.cpp) on the fork's test frames
   (PokemonLZA_Detectors_Tests.cpp, [plza/lean]): its drawn maps and two
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
      "map-pin/zone1-at-north-fence" "(358.5, 228.3)";
    (* The fork's (415.4, 230.4). *)
    case
      "console: the patrol's stop 10, the arrow partly under the zone's badge"
      "map-pin/zone1-stop-10-under-badge" "(414.4, 230.4)";
    case "no map: the 03.03 start" "minimap/es-0303-start" "none";
  ]

let is_map name =
  String.starts_with ~prefix:"map-pin/" name
  || String.starts_with ~prefix:"synthetic/map-" name

(* A shifted map reads within 2 of the frame, or none where it does. Only
   maps: the pin is read with the map open, and other screens have the
   arrow's blue in the window (text boxes, a battle). *)
let shifted_cases =
  List.filter
    (fun (path, _) -> is_map (snd (Fixture_frames.shift_and_frame path)))
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
