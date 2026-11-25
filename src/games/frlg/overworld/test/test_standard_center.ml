(* The coded ground floor of a Center in the shared layout: its warps in pret's
   order, its people, the town's door joined to it, and sb-01's walk
   from Cinnabar's Fly landing to Bill. *)

open Grid_maps
open Frlg_overworld_fixtures
open Frlg_world
module Center = Frlg_overworld.Standard_center
module Route_target = Frlg_overworld.Route_target

let outside : Map_features.warp_destination =
  { to_map = "CinnabarIsland"; to_point = "warp_3" }

let room center =
  match Center.room ~center ~outside with
  | Ok room -> room
  | Error e -> failwith e

let warps center () =
  (room center).warps
  |> List.map (fun (w : Map_features.warp) -> Tile_pos.to_string w.warp_pos)
  |> String.concat " "

let people center () =
  (room center).objects
  |> List.map (fun (o : Map_features.map_object) ->
         o.object_name ^ " " ^ Tile_pos.to_string o.object_pos)
  |> String.concat ", "

let not_standard () =
  match Center.room ~center:"OneIsland_PokemonCenter_1F" ~outside with
  | Ok _ -> "a room"
  | Error e -> e

let cinnabar_names = [ "CinnabarIsland"; "CinnabarIsland_Gym" ]

let world_with_rooms () =
  Frlg_overworld.Frlg_steps.world ~edge_stalls:false ~rock_stairs
    (Connected_maps.create (Center.with_rooms (List.map load cinnabar_names)))

let added () =
  let w = world_with_rooms () in
  string_of_bool
    (Option.is_some
       (Connected_maps.find w.maps "CinnabarIsland_PokemonCenter_1F"))

let walk ~from:(map, x, y, facing) (tx, ty, goal_facing) () =
  let w = world_with_rooms () in
  let goal : Pokemon_checkpoints.Pose.grid =
    {
      map = "CinnabarIsland_PokemonCenter_1F";
      tiles = [ { x = tx; y = ty } ];
      facing = Some goal_facing;
    }
  in
  legs_text w
    (Route_target.plan w ~from:(place w map x y) ~facing:(Some facing) goal)

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "standard_center"
    [
      case "Cinnabar's warps: the mat's middle first, then the stairs"
        (warps "CinnabarIsland_PokemonCenter_1F")
        "(7, 8) (6, 8) (8, 8) (1, 6)";
      case "the mainland's: the mat west to east"
        (warps "ViridianCity_PokemonCenter_1F")
        "(6, 8) (7, 8) (8, 8) (1, 6)";
      case "the Sevii Islands': the mat's middle alone"
        (warps "TwoIsland_PokemonCenter_1F")
        "(7, 8) (1, 6)";
      case "Cinnabar's people, Bill among them"
        (people "CinnabarIsland_PokemonCenter_1F")
        "nurse (7, 2), cooltrainer_f (2, 4), gentleman (9, 7), youngster (14, \
         6), bill (11, 5)";
      case "another Center: the nurse alone"
        (people "PewterCity_PokemonCenter_1F")
        "nurse (7, 2)";
      case "One Island's Center has its own layout" not_standard
        "OneIsland_PokemonCenter_1F does not use LAYOUT_POKEMON_CENTER_1F";
      case "Cinnabar's door brings its Center's room in" added "true";
      case "from the Fly landing up to the counter, held to it"
        (walk ~from:("CinnabarIsland", 14, 12, South) (7, 4, North))
        "north 1 (warp) -> CinnabarIsland_PokemonCenter_1F (7, 8) north; north \
         4 (to wall) -> CinnabarIsland_PokemonCenter_1F (7, 4) north";
      case "from the counter to west of Bill, round the table"
        (walk
           ~from:("CinnabarIsland_PokemonCenter_1F", 7, 4, North)
           (10, 5, East))
        "south 1 -> CinnabarIsland_PokemonCenter_1F (7, 5) south; east 3 (to \
         wall) -> CinnabarIsland_PokemonCenter_1F (10, 5) east";
    ]
