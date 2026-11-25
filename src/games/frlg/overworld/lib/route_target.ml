open Grid_maps
open Grid_geometry
module Pose = Pokemon_engine.Pose
module Pose_text = Pokemon_engine.Pose_text

let place_of (w : Frlg_steps.world) (pose : Pose.observed) =
  match Connected_maps.find w.maps pose.at_map with
  | Some map -> Ok { Connected_maps.map; tile = pose.at_tile }
  | None -> Error (Printf.sprintf "map %s is not loaded" pose.at_map)

let observed_of (w : Frlg_steps.world) (place : Connected_maps.place) faces =
  {
    Pose.at_map = (Connected_maps.map w.maps place.map).name;
    at_tile = place.tile;
    faces;
  }

let at_target (w : Frlg_steps.world) (target : Pose.grid)
    (place : Connected_maps.place) =
  (Connected_maps.map w.maps place.map).name = target.map
  && (target.tiles = [] || List.exists (Tile_pos.equal place.tile) target.tiles)

let plan w ~from ~facing (target : Pose.grid) =
  match Connected_maps.find w.Frlg_steps.maps target.map with
  | None -> Error (Printf.sprintf "map %s is not loaded" target.map)
  | Some _ -> (
      match
        Grid_planning.Leg_planner.plan (Frlg_steps.model w) ~start:from
          ~start_facing:facing ~at_goal:(at_target w target)
          ~goal_facing:target.facing
      with
      | Some legs -> Ok legs
      | None -> Error ("no walk reaches " ^ Pose_text.grid target))
