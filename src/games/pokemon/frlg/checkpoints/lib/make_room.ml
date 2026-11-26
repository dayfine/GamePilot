module Towns = Frlg_actions.Fly_towns
module R = Room_policy
module Places = Frlg_places.Place_table
module Maps = Grid_maps.Connected_maps

let id = "00-make-room"
let pc_front = Frlg_overworld.Standard_center.pc_front

type center = { town : Towns.town; map : string }

let direct_town (t : Towns.t) map =
  List.find_opt
    (fun (town : Towns.town) -> map = town.name || map = town.landing.at_map)
    t.towns

let indoor_map maps name =
  Option.bind (Maps.find maps name) (fun i ->
      let m = Maps.map maps i in
      if m.allow_running then None else Some m)

let warp_targets (m : Grid_maps.Map_data.t) =
  List.filter_map
    (fun (w : Grid_maps.Map_features.warp) ->
      Option.map
        (fun (d : Grid_maps.Map_features.warp_destination) -> d.to_map)
        w.destination)
    m.warps

let indoor_warps maps name =
  Option.fold ~none:[] ~some:warp_targets (indoor_map maps name)

let rec search_indoor t maps seen = function
  | [] -> None
  | name :: rest when List.mem name seen -> search_indoor t maps seen rest
  | name :: rest -> (
      match direct_town t name with
      | Some _ as found -> found
      | None ->
          search_indoor t maps (name :: seen) (rest @ indoor_warps maps name))

let town_of_map (t : Towns.t) ~maps map =
  match direct_town t map with
  | Some town -> Some town
  | None -> (
      match indoor_map maps map with
      | None -> None
      | Some _ -> search_indoor t maps [] [ map ])

let distance (a : Grid_geometry.Tile_pos.t) (b : Grid_geometry.Tile_pos.t) =
  ((a.x - b.x) * (a.x - b.x)) + ((a.y - b.y) * (a.y - b.y))

(* A Center Make_room can walk: its coded room, with the PC at pc_front. *)
let standard_center places maps (town : Towns.town) =
  Option.bind (Places.center_map_of_fly places town.name) (fun map ->
      if
        Frlg_overworld.Standard_center.is_standard map
        && Option.is_some (Maps.find maps map)
      then Some { town; map }
      else None)

let nearest_center (t : Towns.t) ~places ~maps map =
  match town_of_map t ~maps map with
  | None -> Error (map ^ " is in no Fly town: give a town's map")
  | Some here -> (
      let with_center = List.filter_map (standard_center places maps) t.towns in
      let nearer a b =
        if distance b.town.cell here.cell < distance a.town.cell here.cell then
          b
        else a
      in
      match with_center with
      | [] -> Error "no Fly town has a standard Center in the maps"
      | first :: rest -> Ok (List.fold_left nearer first rest))

type room = {
  center : center;
  deposits : R.plan;
  party : R.member list;
  needed_moves : string list;
}

let pose map (tile : Grid_geometry.Tile_pos.t) facing =
  `Assoc
    [
      ("map", `String map);
      ("tiles", `List [ `List [ `Int tile.x; `Int tile.y ] ]);
      ("facing", `String facing);
    ]

let opt key f = Option.fold ~none:[] ~some:(fun v -> [ (key, f v) ])
let string s = `String s

let event id kind ?action ?(args = []) ?after why =
  let args = if args = [] then [] else [ ("args", `Assoc args) ] in
  `Assoc
    ([ ("id", string id); ("kind", string kind) ]
    @ opt "action" string action @ args
    @ opt "declared_after" Fun.id after
    @ [ ("why", string why) ])

let route id target why =
  event id "route" ~action:"run" ~args:[ ("target", target) ] why

let landing room =
  pose room.center.town.landing.at_map room.center.town.landing.at_tile "south"

let pc room = pose room.center.map pc_front "north"
let deposited room = List.map (fun (d : R.deposit) -> d.species) room.deposits

let events room =
  let town = room.center.town.name in
  [
    event "fly_to_center" "game_action" ~action:"fly"
      ~args:[ ("town", `String town) ]
      ~after:(landing room)
      ("Fly to " ^ town ^ ", the Center nearest the save");
    route "to_pc" (pc room) "below the Center's PC (11, 1), facing it";
    event "deposit" "game_action" ~action:"pc_deposit"
      ~args:
        [ ("species", `List (List.map (fun s -> `String s) (deposited room))) ]
      ~after:(pc room) "the room policy's members to the PC";
    route "out_of_center" (landing room) "out to the Fly landing";
  ]

let kept room =
  List.filter
    (fun (m : R.member) -> not (List.mem m.species (deposited room)))
    room.party

let knows_move move (m : R.member) =
  Option.fold ~none:false ~some:(List.mem move) m.moves

let knows_json move (m : R.member) =
  `Assoc [ ("species", string m.species); ("moves", `List [ string move ]) ]

(* Each needed move, with the first member left that knows it. *)
let knows room =
  List.filter_map
    (fun move ->
      Option.map (knows_json move) (List.find_opt (knows_move move) (kept room)))
    room.needed_moves

let postconditions room =
  `Assoc
    [
      ("position", landing room);
      ( "party",
        `List (List.map (fun (m : R.member) -> `String m.species) (kept room))
      );
      ("knows", `List (knows room));
    ]

let checkpoint room =
  `Assoc
    [
      ("id", string id);
      ("title", string "make room: deposit at the nearest Center's PC");
      ("events", `List (events room));
    ]

let metadata room =
  `Assoc
    [ ("phase", string "generated"); ("postconditions", postconditions room) ]

let room_plan room =
  `Assoc
    [
      ("format", string "gamepilot-checkpoint/1");
      ("game", string "frlg");
      ("checkpoint", checkpoint room);
      ("execution", `Assoc [ ("menu", string "full") ]);
      ("metadata", metadata room);
    ]
