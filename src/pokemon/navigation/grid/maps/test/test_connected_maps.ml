(* A town with a route north of it and a lake east of it, joined by their
   places on one world grid (connect_by_world), and a house the town's door
   warps into. Ported from Pokemon_ConnectedMaps_Tests.cpp.

       world x:  -1  0  1  2  3  4  5
       y 0..2:   [ Route (6 wide) ]
       y 3..5:      [ Town (4) ][Lake]                                    *)

open Grid_maps
open Grid_geometry

let open_map ?world ?(points = "{}") name ~width ~height =
  let row = Printf.sprintf "%S" (String.make width '.') in
  let world =
    match world with
    | Some (x, y) ->
        Printf.sprintf {|"world": {"name": "Test", "x": %d, "y": %d},|} x y
    | None -> ""
  in
  let json =
    Printf.sprintf
      {|{"name": %S, "source": {"decomp_file": "f", "revision": "r", "date": "d"}, %s "points": %s, "tiles": [%s]}|}
      name world points
      (String.concat ", " (List.init height (fun _ -> row)))
  in
  Result.get_ok (Map_file.of_string ~source_name:name json)

let world =
  Connected_maps.create
    (Connected_maps.connect_by_world
       [
         open_map "Town" ~width:4 ~height:3 ~world:(0, 3);
         open_map "Route" ~width:6 ~height:3 ~world:(-1, 0);
         open_map "Lake" ~width:2 ~height:3 ~world:(4, 3);
         open_map "House" ~width:2 ~height:2 ~points:{|{"door": [0, 1]}|};
       ])

(* A tile named by its map's name. *)
type named_place = string * Tile_pos.t

let describe = function
  | None -> "nowhere"
  | Some (place : Connected_maps.place) ->
      (Connected_maps.map world place.map).name ^ " "
      ^ Tile_pos.to_string place.tile

let place_of ((name, tile) : named_place) : Connected_maps.place =
  { map = Option.get (Connected_maps.find world name); tile }

let lands_on what ~(expected : named_place option) actual =
  Check.equal what
    ~expected:(describe (Option.map place_of expected))
    (describe actual)

type step_case = {
  name : string;
  input : named_place * Direction.t;
  expectation : named_place option;
}

let step_cases =
  [
    {
      name = "a step on the same map";
      input = (("Town", { x = 1; y = 1 }), East);
      expectation = Some ("Town", { x = 2; y = 1 });
    };
    {
      name = "north onto the route, shifted by its offset";
      input = (("Town", { x = 0; y = 0 }), North);
      expectation = Some ("Route", { x = 1; y = 2 });
    };
    {
      name = "south off the route into the town";
      input = (("Route", { x = 1; y = 2 }), South);
      expectation = Some ("Town", { x = 0; y = 0 });
    };
    {
      name = "east into the lake";
      input = (("Town", { x = 3; y = 2 }), East);
      expectation = Some ("Lake", { x = 0; y = 2 });
    };
    {
      name = "west into the town";
      input = (("Lake", { x = 0; y = 1 }), West);
      expectation = Some ("Town", { x = 3; y = 1 });
    };
    {
      name = "north out of the lake onto the route's last column";
      input = (("Lake", { x = 0; y = 0 }), North);
      expectation = Some ("Route", { x = 5; y = 2 });
    };
    {
      name = "north out of the lake past the route's span";
      input = (("Lake", { x = 1; y = 0 }), North);
      expectation = None;
    };
    {
      name = "an edge no map joins";
      input = (("Town", { x = 0; y = 1 }), West);
      expectation = None;
    };
    {
      name = "past the joined map's span";
      input = (("Route", { x = 0; y = 2 }), South);
      expectation = None;
    };
    {
      name = "a map off the world grid joins nothing";
      input = (("House", { x = 1; y = 0 }), North);
      expectation = None;
    };
  ]

let run_step { name; input = from, direction; expectation } =
  Table_test.report name
    (lands_on "step" ~expected:expectation
       (Connected_maps.neighbour world (place_of from) direction))

type warp_case = {
  warp_name : string;
  destination : Map_features.warp_destination option;
  arrival : named_place option;
}

let warp_cases =
  [
    {
      warp_name = "a warp to a loaded map's point";
      destination = Some { to_map = "House"; to_point = "door" };
      arrival = Some ("House", { x = 0; y = 1 });
    };
    {
      warp_name = "a warp to a map that isn't loaded";
      destination = Some { to_map = "Cave"; to_point = "door" };
      arrival = None;
    };
    {
      warp_name = "a warp to a point the map lacks";
      destination = Some { to_map = "House"; to_point = "stairs" };
      arrival = None;
    };
    {
      warp_name = "a warp that leads nowhere";
      destination = None;
      arrival = None;
    };
  ]

let run_warp { warp_name; destination; arrival } =
  let warp : Map_features.warp =
    {
      warp_pos = { x = 0; y = 0 };
      enter = Walk_into;
      destination;
      one_way = false;
    }
  in
  Table_test.report warp_name
    (lands_on "arrival" ~expected:arrival
       (Connected_maps.warp_arrival world warp))

(* A place whose map index is past the maps (from another world) is a
   programming error, not a read past the end. *)
type stale_case = { stale_name : string; map_index : int; rejected : bool }

let stale_cases =
  [
    {
      stale_name = "the last map index is read";
      map_index = 3;
      rejected = false;
    };
    {
      stale_name = "a map index one past the last is rejected";
      map_index = 4;
      rejected = true;
    };
    {
      stale_name = "a map index far past the last is rejected";
      map_index = 1000;
      rejected = true;
    };
  ]

let run_stale { stale_name; map_index; rejected } =
  let place : Connected_maps.place =
    { map = map_index; tile = { x = 0; y = 0 } }
  in
  let was_rejected =
    match Connected_maps.neighbour world place North with
    | _ -> false
    | exception Invalid_argument _ -> true
  in
  Table_test.report stale_name
    (Check.equal "rejected" ~expected:(string_of_bool rejected)
       (string_of_bool was_rejected))

let () =
  List.iter run_step step_cases;
  List.iter run_warp warp_cases;
  List.iter run_stale stale_cases;
  Table_test.finish ()
