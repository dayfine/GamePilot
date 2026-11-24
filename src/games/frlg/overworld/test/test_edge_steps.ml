(* Holds over FireRed's map edges and rock stairs against mGBA, measured
   2026-11-23: from save states near each edge, a direction held from standing
   (facing that way) and the player's tile read from RAM every frame. Each case
   lists the frame (from the press) each step started on. A hold planned for k
   tiles must let go after step k starts and before step k+1 does; the cases
   check every k.

   What they show: no edge holds the player up on mGBA (a step onto another
   map takes one or two frames more than the 8 of a running step, as some
   steps inside a map do), and the steps on Indigo Plateau's and Route 23's
   rock stairs (north off one, south onto one) take 11 or 12 frames running
   and 23 walking. The old rule with no slow steps let go of "south 15" from
   the Fly spot two tiles early, on Route 23 (11, 0), as mg-04 runs 10 and 12
   ended. *)

open Grid_maps
open Frlg_overworld_fixtures
open Frlg_world
module Route_legs = Frlg_overworld.Route_legs

let gba_frames_per_s = 59.7275

let maps =
  [
    "CeladonCity";
    "Route16";
    "LavenderTown";
    "Route8";
    "Route10";
    "IndigoPlateau_Exterior";
    "Route23";
  ]

let w = mgba_world maps

(* The place [k] presses of [d] from [from] reach. *)
let rec pressed from d k =
  if k = 0 then Some from
  else
    Option.bind (Frlg_overworld.Frlg_steps.press w from d) (fun step ->
        pressed step.Grid_planning.Leg.next d (k - 1))

(* The open leg of [k] tiles [d] from [from] to [target], as the walker holds
   it. *)
let hold_frames gait from d k target =
  let leg : Connected_maps.place Grid_planning.Leg.t =
    {
      kind = Walk { tiles = k; to_wall = false };
      direction = d;
      warps = false;
      wild = false;
      facing_after = d;
      start = from;
      finish = target;
    }
  in
  match Route_legs.move_of w gait ~facing:(Some d) leg with
  | Ok (Hold { spec; _ }) ->
      let ms = Grid_walker.Leg_timing.hold_ms spec spec.tiles in
      Ok (float_of_int ms *. gba_frames_per_s /. 1000.)
  | Ok (Turn _) -> Error "a turn"
  | Error e -> Error e

(* Where each hold of 1 to n tiles lets go, against the measured step starts:
   the holds that land elsewhere, or that all land. *)
let measured gait ~ends (map, x, y) d starts () =
  let from = place w map x y in
  let n = List.length starts in
  let landed frames =
    List.length (List.filter (fun s -> float_of_int s < frames) starts)
  in
  let check k =
    match pressed from d k with
    | None -> Some (Printf.sprintf "%d: no step" k)
    | Some target -> (
        match hold_frames gait from d k target with
        | Error e -> Some (Printf.sprintf "%d: %s" k e)
        | Ok frames when landed frames = k -> None
        | Ok frames ->
            Some
              (Printf.sprintf "%s %d lands %d (held %.1f frames)"
                 (Direction.name d) k (landed frames) frames))
  in
  let last =
    match pressed from d n with Some p -> place_text w p | None -> "nowhere"
  in
  let wrong = List.filter_map check (List.init n (fun i -> i + 1)) in
  let ends_text =
    let map, x, y = ends in
    place_text w (place w map x y)
  in
  if last <> ends_text then "the steps end on " ^ last ^ ", not " ^ ends_text
  else if wrong = [] then Printf.sprintf "all %d holds land" n
  else String.concat "; " wrong

let case name test n =
  {
    Case_table.name;
    input = test;
    expectation = Printf.sprintf "all %d holds land" n;
  }

let () =
  Case_table.run "edge_steps"
    [
      case "Celadon City west onto Route 16"
        (measured Running ~ends:("Route16", 38, 14) ("CeladonCity", 5, 24) West
           [ 1; 9; 17; 25; 33; 41; 50; 58; 66; 74; 82; 90; 98; 106; 114 ])
        15;
      case "Route 16 east onto Celadon City"
        (measured Running ~ends:("CeladonCity", 12, 24) ("Route16", 45, 14) East
           [ 1; 9; 17; 26; 34; 42; 50; 58; 66; 74; 82; 90; 98; 106; 114 ])
        15;
      case "Lavender Town west onto Route 8"
        (measured Running ~ends:("Route8", 62, 10) ("LavenderTown", 1, 10) West
           [ 1; 9; 18; 26; 34; 42; 50; 58; 66; 74; 82 ])
        11;
      case "Route 8 east onto Lavender Town"
        (measured Running ~ends:("LavenderTown", 7, 10) ("Route8", 68, 10) East
           [ 1; 9; 17; 25; 34; 43; 51; 59; 67; 75; 83 ])
        11;
      case "Lavender Town north onto Route 10"
        (measured Running ~ends:("Route10", 10, 76) ("LavenderTown", 10, 2)
           North [ 1; 9; 17; 27; 35; 43 ])
        6;
      case "Route 10 south onto Lavender Town"
        (measured Running ~ends:("LavenderTown", 10, 6) ("Route10", 10, 76)
           South
           [ 1; 9; 17; 25; 34; 43; 51; 59; 67; 75 ])
        10;
      case "Indigo Plateau south onto Route 23"
        (measured Running ~ends:("Route23", 11, 8)
           ("IndigoPlateau_Exterior", 11, 17)
           South
           [ 1; 12; 20; 33; 41; 49; 57; 65; 73; 81; 89 ])
        11;
      case "Route 23 north onto Indigo Plateau"
        (measured Running
           ~ends:("IndigoPlateau_Exterior", 11, 10)
           ("Route23", 11, 4) North
           [ 1; 9; 17; 25; 33; 46; 54; 65; 73; 84; 92; 103; 111; 119 ])
        14;
      case "Indigo Plateau south from the Fly spot"
        (measured Running ~ends:("Route23", 11, 0)
           ("IndigoPlateau_Exterior", 11, 7)
           South
           [ 1; 9; 17; 25; 33; 42; 50; 61; 69; 80; 88; 99; 107 ])
        13;
      case "Indigo Plateau south from the Fly spot, walking"
        (measured Walking ~ends:("Route23", 11, 0)
           ("IndigoPlateau_Exterior", 11, 7)
           South
           [ 1; 17; 33; 49; 65; 82; 98; 121; 137; 160; 176; 199; 215 ])
        13;
    ]
