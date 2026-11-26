let flags = [ "FLAG_HIDE_TWO_ISLAND_GAME_CORNER_BIKER" ]

let hidden (o : Grid_maps.Map_features.map_object) =
  match o.hide_flag with Some flag -> List.mem flag flags | None -> false
