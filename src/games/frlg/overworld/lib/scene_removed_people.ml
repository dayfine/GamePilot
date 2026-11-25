let flags =
  [ "FLAG_HIDE_THREE_ISLAND_BIKERS"; "FLAG_HIDE_THREE_ISLAND_LONE_BIKER" ]

let hidden (o : Grid_maps.Map_features.map_object) =
  match o.hide_flag with Some flag -> List.mem flag flags | None -> false
