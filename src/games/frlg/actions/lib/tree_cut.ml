let cut world (at : Pokemon_checkpoints.Pose.observed) direction =
  let on_tree =
    {
      Pokemon_checkpoints.Pose.at_map = at.at_map;
      at_tile = Grid_geometry.Tile_pos.next at.at_tile direction;
      faces = Some direction;
    }
  in
  let opened =
    match Frlg_overworld.Route_target.place_of world on_tree with
    | Ok place -> Frlg_overworld.Frlg_steps.with_tree_cut world place
    | Error _ -> None
  in
  (Option.value opened ~default:world, on_tree)

let regrown world ~before ~after =
  if after <> before then Frlg_overworld.Frlg_steps.trees_regrown world
  else world
