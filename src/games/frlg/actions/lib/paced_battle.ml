let reckoned = function
  | Some at -> at
  | None -> Menu_input.fail "position_unknown" "no position to pace from"

let off_patch ~patch (at : Pokemon_engine.Pose.observed) =
  Menu_input.fail "off_patch"
    (Printf.sprintf "%s is not the patch %s or next to it"
       (Grid_geometry.Tile_pos.to_string at.at_tile)
       (Grid_geometry.Tile_pos.to_string patch))

let no_encounter () =
  Menu_input.fail "no_encounter"
    (Printf.sprintf "no wild battle in %d steps" Pacing.max_steps)

let standing ~pace ~patch (at : Pokemon_engine.Pose.observed)
    (spot : Pacing.spot) =
  { at with at_tile = Pacing.stands_on ~pace spot patch; faces = spot.facing }

let pace_from ~log ~pace ~patch ~stands at spot =
  let spot = ref spot in
  let found = Pacing_steps.find_encounter ~log ~pace spot in
  stands (standing ~pace ~patch at !spot);
  if not found then no_encounter ()

let find ~log ~pace ~patch ~stands (at : Pokemon_engine.Pose.observed) =
  match Pacing.spot_at ~pace ~patch at.at_tile at.faces with
  | None -> off_patch ~patch at
  | Some spot -> pace_from ~log ~pace ~patch ~stands at spot

let back_on_patch ~pace (start : Pokemon_engine.Pose.observed) :
    Pokemon_engine.Pose.grid =
  { map = start.at_map; tiles = [ start.at_tile ]; facing = Some pace }
