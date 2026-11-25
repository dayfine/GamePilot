open Grid_maps

let mat : Tile_pos.t = { x = 7; y = 8 }
let nurse_front : Tile_pos.t = { x = 7; y = 4 }
let pc_front : Tile_pos.t = { x = 11; y = 2 }

let centers =
  [
    "CeladonCity_PokemonCenter_1F";
    "CeruleanCity_PokemonCenter_1F";
    "CinnabarIsland_PokemonCenter_1F";
    "FiveIsland_PokemonCenter_1F";
    "FourIsland_PokemonCenter_1F";
    "FuchsiaCity_PokemonCenter_1F";
    "LavenderTown_PokemonCenter_1F";
    "PewterCity_PokemonCenter_1F";
    "Route10_PokemonCenter_1F";
    "Route4_PokemonCenter_1F";
    "SaffronCity_PokemonCenter_1F";
    "SevenIsland_PokemonCenter_1F";
    "SixIsland_PokemonCenter_1F";
    "ThreeIsland_PokemonCenter_1F";
    "TwoIsland_PokemonCenter_1F";
    "VermilionCity_PokemonCenter_1F";
    "ViridianCity_PokemonCenter_1F";
  ]

let is_standard name = List.mem name centers

(* The fork's CENTER_ROOM_JSON (Overworld/PokemonFRLG_CodedRooms.cpp) in the
   runtime map format: LAYOUT_POKEMON_CENTER_1F's collision and elevation from
   pokefirered data/layouts/PokemonCenter_1F/map.bin at ce6406d8, the nurse
   and the PC's stand; %s are the name, the points, the warps and the people. *)
let room_text : (_, unit, string) format =
  {|{
  "format": "pokesim-runtime-map/2",
  "name": "%s",
  "source": {
    "decomp_file": "data/layouts/PokemonCenter_1F/map.bin",
    "revision": "ce6406d8c2eaf46d543c8a2606de0c3cb1951982",
    "date": "2026-11-09"
  },
  "allow_running": false,
  "tiles": ["#.#############", "###############", "....###..##....",
            "....#######....", "...............", "...............",
            "#..........##..", "...........##..", "...............",
            "###############"],
  "elevation": ["030000000000000", "000000000000000", "333300033003333",
                "333300000003333", "333333333333333", "330333333333333",
                "044033333330033", "330333333330033", "333333333333333",
                "000000000000000"],
  "points": {%s"mat": [7, 8], "nurse_front": [7, 4], "pc_front": [11, 2]},
  "warps": [%s
    {"coord": [1, 6], "enter": "step_on", "to_map": "%s_PokemonCenter_2F",
     "to_point": "warp_0"}],
  "npcs": [
    {"name": "nurse", "coord": [7, 2], "facing": "south",
     "source_script": "%s_EventScript_Nurse"}%s]
}|}

(* The fork's people (pokemon_center_room()), with their pret scripts
   (pokefirered data/maps/<Center>/map.json); Bill is ours, hidden until the
   story frees him after Blaine: the fork's story never meets him there. *)
let cinnabar_people =
  {|,
    {"name": "cooltrainer_f", "coord": [2, 4], "wander": {"min": [1, 4], "max": [3, 4]},
     "source_script": "CinnabarIsland_PokemonCenter_1F_EventScript_CooltrainerF"},
    {"name": "gentleman", "coord": [9, 7], "wander": {"min": [8, 6], "max": [10, 8]},
     "source_script": "CinnabarIsland_PokemonCenter_1F_EventScript_Gentleman"},
    {"name": "youngster", "coord": [14, 6], "facing": "west",
     "source_script": "CinnabarIsland_PokemonCenter_1F_EventScript_Youngster"},
    {"name": "bill", "coord": [11, 5], "facing": "south",
     "hide_flag": "FLAG_HIDE_CINNABAR_POKECENTER_BILL",
     "source_script": "CinnabarIsland_PokemonCenter_1F_EventScript_Bill"}|}

let saffron_people =
  {|,
    {"name": "woman_3", "coord": [4, 4], "wander": {"min": [3, 3], "max": [5, 5]},
     "source_script": "SaffronCity_PokemonCenter_1F_EventScript_Woman3"},
    {"name": "youngster", "coord": [9, 6], "wander": {"min": [9, 5], "max": [9, 7]},
     "source_script": "SaffronCity_PokemonCenter_1F_EventScript_Youngster"},
    {"name": "gentleman", "coord": [14, 6], "facing": "west",
     "source_script": "SaffronCity_PokemonCenter_1F_EventScript_Gentleman"}|}

let town_of center =
  match String.index_opt center '_' with
  | Some i -> String.sub center 0 i
  | None -> center

let people center =
  match town_of center with
  | "CinnabarIsland" -> cinnabar_people
  | "SaffronCity" -> saffron_people
  | _ -> ""

let sevii =
  [
    "TwoIsland";
    "ThreeIsland";
    "FourIsland";
    "FiveIsland";
    "SixIsland";
    "SevenIsland";
  ]

(* The mat's warps in each Center's map.json order, so "warp_<n>" is pret's:
   the mainland's list the mat west to east, Cinnabar's starts in the middle,
   and the Sevii Islands' (Two to Seven) have the middle tile alone. *)
let mat_order center =
  if town_of center = "CinnabarIsland" then [ 7; 6; 8 ]
  else if List.mem (town_of center) sevii then [ 7 ]
  else [ 6; 7; 8 ]

let mat_points center =
  List.mapi (Printf.sprintf "\"warp_%d\": [%d, 8], ") (mat_order center)
  |> String.concat ""

let mat_warp (outside : Map_features.warp_destination) x =
  Printf.sprintf
    {|
    {"coord": [%d, 8], "enter": "%s", "to_map": "%s", "to_point": "%s"},|}
    x
    (if x = mat.x then "walk_south" else "walk_into")
    outside.to_map outside.to_point

let room ~center ~outside =
  if not (is_standard center) then
    Error (center ^ " does not use LAYOUT_POKEMON_CENTER_1F")
  else
    Map_file.of_string ~source_name:("coded " ^ center)
      (Printf.sprintf room_text center (mat_points center)
         (String.concat "" (List.map (mat_warp outside) (mat_order center)))
         (town_of center) center (people center))

(* The fork's add_pokemon_center_room(): the town gets a point
   "<Center>_door" on its door, for the mat's warps to land on. *)
let with_door_point (town : Map_data.t) (door : Tile_pos.t) center =
  let name = center ^ "_door" in
  ({ town with points = Map_data.String_map.add name door town.points }, name)

let loaded maps name = List.exists (fun (m : Map_data.t) -> m.name = name) maps

(* The first unmapped standard Center whose door is on [town]. *)
let unmapped_door maps (town : Map_data.t) =
  List.find_map
    (fun (w : Map_features.warp) ->
      match w.destination with
      | Some d when is_standard d.to_map && not (loaded maps d.to_map) ->
          Some (w.warp_pos, d.to_map)
      | _ -> None)
    town.warps

let add_room maps (towns, rooms) (town : Map_data.t) =
  match unmapped_door (maps @ rooms) town with
  | None -> (town :: towns, rooms)
  | Some (door, center) -> (
      let town, point = with_door_point town door center in
      match room ~center ~outside:{ to_map = town.name; to_point = point } with
      | Ok r -> (town :: towns, r :: rooms)
      | Error _ -> (town :: towns, rooms))

let with_rooms maps =
  let towns, rooms = List.fold_left (add_room maps) ([], []) maps in
  List.rev towns @ List.rev rooms
