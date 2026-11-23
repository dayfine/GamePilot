(* The decomp's preview sections, as the prefixes of the PokemonSimulation map
   names in them. A section is a region map section, which a name prefix only
   stands for: the Tanoby chambers share one prefix here. *)
let sections =
  [
    "ViridianForest";
    "MtMoon_";
    "DiglettsCave_";
    "RockTunnel_";
    "PokemonTower_";
    "SafariZone_";
    "SeafoamIslands_";
    "PokemonMansion_";
    "RocketHideout_";
    "SilphCo_";
    "VictoryRoad_";
    "CeruleanCave_";
    "PowerPlant";
    "MtEmber_";
    "FiveIsland_RocketWarehouse";
    "SevenIsland_TanobyRuins_";
    "SixIsland_DottedHole";
    "ThreeIsland_BerryForest";
    "FourIsland_IcefallCave_";
    "FiveIsland_LostCave";
    "SixIsland_AlteringCave";
    "SixIsland_PatternBush";
  ]

let section name =
  List.find_opt (fun prefix -> String.starts_with ~prefix name) sections

let on_warp ~from_map ~to_map =
  match section to_map with
  | None -> false
  | Some s -> section from_map <> Some s

let watch_ms = 3500

(* mGBA, 2026-11-23, into Pokemon Tower 1F: white 8 frames after the picture,
   black 22 frames after the white came up, the map 12 frames later. *)
let fade_gap_ms = 1000
