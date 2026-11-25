module Towns = Frlg_actions.Fly_towns
module R = Room_policy

let id = "00-make-room"
let center_map town = town ^ "_PokemonCenter_1F"
let pc_front = Frlg_overworld.Standard_center.pc_front

let town_of_map (t : Towns.t) map =
  List.find_opt
    (fun (town : Towns.town) ->
      map = town.name || String.starts_with ~prefix:(town.name ^ "_") map)
    t.towns

let distance (a : Grid_geometry.Tile_pos.t) (b : Grid_geometry.Tile_pos.t) =
  ((a.x - b.x) * (a.x - b.x)) + ((a.y - b.y) * (a.y - b.y))

(* A Center Make_room can walk: its coded room, with the PC at pc_front. *)
let has_standard_center maps (town : Towns.town) =
  let center = center_map town.name in
  Frlg_overworld.Standard_center.is_standard center && List.mem center maps

let nearest_center (t : Towns.t) ~maps map =
  match town_of_map t map with
  | None -> Error (map ^ " is in no Fly town: give a town's map")
  | Some here -> (
      let with_center = List.filter (has_standard_center maps) t.towns in
      let nearer (a : Towns.town) (b : Towns.town) =
        if distance b.cell here.cell < distance a.cell here.cell then b else a
      in
      match with_center with
      | [] -> Error "no Fly town has a standard Center in the maps"
      | first :: rest -> Ok (List.fold_left nearer first rest))

type room = {
  center : Towns.town;
  fly_user : string;
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
  pose room.center.landing.at_map room.center.landing.at_tile "south"

let pc room = pose (center_map room.center.name) pc_front "north"
let deposited room = List.map (fun (d : R.deposit) -> d.species) room.deposits

let events room =
  let town = room.center.name in
  [
    event "fly_to_center" "game_action" ~action:"fly"
      ~args:[ ("town", `String town); ("species", `String room.fly_user) ]
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

let plan_json room =
  `Assoc
    [
      ("format", string "gamepilot-checkpoint/1");
      ("game", string "frlg");
      ("checkpoint", checkpoint room);
      ("execution", `Assoc [ ("menu", string "full") ]);
      ("metadata", metadata room);
    ]
