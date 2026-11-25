open Grid_maps
module L = Frlg_actions.Lift_ride
module Pose = Checkpoints.Pose

type fields = (string * Yojson.Safe.t) list

let ( let* ) = Result.bind
let fields_of = function `Assoc f -> f | _ -> []

let assoc key fields =
  fields_of (Option.value ~default:`Null (List.assoc_opt key fields))

let str key fields =
  match List.assoc_opt key fields with Some (`String s) -> Some s | _ -> None

let set key value fields =
  if List.mem_assoc key fields then
    List.map (fun (k, v) -> if k = key then (k, value) else (k, v)) fields
  else fields @ [ (key, value) ]

let without key fields = List.filter (fun (k, _) -> k <> key) fields
let tile_json (t : Tile_pos.t) = `List [ `Int t.x; `Int t.y ]

let facing_field = function
  | Some d -> [ ("facing", `String (Direction.name d)) ]
  | None -> []

let pose_json (g : Pose.grid) : Yojson.Safe.t =
  let tiles = `List (List.map tile_json g.tiles) in
  `Assoc ([ ("map", `String g.map); ("tiles", tiles) ] @ facing_field g.facing)

let observed_json (o : Pose.observed) =
  pose_json { map = o.at_map; tiles = [ o.at_tile ]; facing = o.faces }

let one_tile = function
  | Some (`List [ `List [ `Int x; `Int y ] ]) -> Some { Tile_pos.x; y }
  | _ -> None

(* A one-tile grid pose's JSON as where the player stands. *)
let observed_of_json json : Pose.observed option =
  let f = fields_of json in
  match (str "map" f, one_tile (List.assoc_opt "tiles" f)) with
  | Some at_map, Some at_tile ->
      let faces = Option.bind (str "facing" f) Direction.of_name in
      Some { Pose.at_map; at_tile; faces }
  | _ -> None

(* Where an event says it leaves the player, if it says. *)
let after_event (event : fields) =
  let args = assoc "args" event in
  match (str "kind" event, str "action" event) with
  | Some "route", _ ->
      Option.bind (List.assoc_opt "target" args) observed_of_json
  | Some "game_action", Some "lift_floor" ->
      Result.to_option (L.ride_of_args args) |> Option.map L.arrival
  | _ -> None

(* Where the player stands after the event, as the runner reckons it. *)
let reckon at event =
  match after_event event with
  | Some _ as after -> after
  | None -> (
      match
        Option.bind (List.assoc_opt "declared_after" event) observed_of_json
      with
      | Some _ as declared -> declared
      | None -> at)

(* The place a route event names as its target, if it names one. *)
let place_name event =
  let target = assoc "target" (assoc "args" event) in
  match (str "kind" event, List.assoc_opt "place" target) with
  | Some "route", Some (`String name) -> Some (Ok name)
  | Some "route", Some _ -> Some (Error "target.place is not a string.")
  | _ -> None

let route_to (g : Pose.grid) event =
  set "args" (`Assoc (set "target" (pose_json g) (assoc "args" event))) event

let floors (a : Lift_stops.stop) (b : Lift_stops.stop) =
  if a.floor = b.floor then Ok None else Ok (Some (a, b))

(* The floors to ride between, if the walk changes floors on a lift. *)
let ride (at : Pose.observed) (place : Place_table.place) =
  let off (s : Lift_stops.stop) = Lift_stops.way_out s.lift in
  match (Lift_stops.of_map at.at_map, Lift_stops.of_map place.map) with
  | None, None -> Ok None
  | Some from, None -> floors from (off from)
  | None, Some to_ -> floors (off to_) to_
  | Some from, Some to_ when from.lift = to_.lift -> floors from to_
  | Some from, Some to_ ->
      Error
        (Printf.sprintf "the walk from %s to %s crosses two lifts." from.map
           to_.map)

let lift_event id event (from : Lift_stops.stop) (to_ : Lift_stops.stop) =
  let args = [ ("from", `String from.floor); ("to", `String to_.floor) ] in
  let arrival = Result.to_option (Result.map L.arrival (L.ride_of_args args)) in
  let declared =
    Option.fold ~none:[]
      ~some:(fun a -> [ ("declared_after", observed_json a) ])
      arrival
  in
  let why = Printf.sprintf "ride the lift from %s to %s" from.floor to_.floor in
  let event =
    [
      ("id", `String (id ^ ".lift"));
      ("kind", `String "game_action");
      ("action", `String "lift_floor");
      ("args", `Assoc args);
    ]
    @ declared
    @ List.filter (fun (k, _) -> k = "skip_if") event
    @ [ ("why", `String why) ]
  in
  (`Assoc event, arrival)

let with_ride id event (place : Place_table.place)
    ((from : Lift_stops.stop), (to_ : Lift_stops.stop)) =
  let target = Place_table.pose place in
  let why =
    Printf.sprintf "to below the %s lift door, for %s" from.floor place.name
  in
  let to_door =
    route_to from.door event |> without "declared_after"
    |> set "why" (`String why)
  in
  let lift, arrival = lift_event id event from to_ in
  let walk = route_to target event |> set "id" (`String (id ^ ".walk")) in
  let arrived = Option.fold ~none:false ~some:(Pose.matches target) arrival in
  [ `Assoc to_door; lift ] @ if arrived then [] else [ `Assoc walk ]

let unknown_start =
  "where the player stands before it is not known: give the checkpoint a \
   start, or the event before it a one-tile declared_after."

let to_place places at event name =
  let* place = Place_table.find places name in
  let* at = Option.to_result ~none:unknown_start at in
  let* floors = ride at place in
  let id = Option.value ~default:"" (str "id" event) in
  match floors with
  | None -> Ok [ `Assoc (route_to (Place_table.pose place) event) ]
  | Some floors -> Ok (with_ride id event place floors)

let expand_event places at event =
  match place_name event with
  | None -> Ok [ `Assoc event ]
  | Some name -> Result.bind name (to_place places at event)

(* The event expanded, its error naming it as the [i]th. *)
let expand_nth places ~where at i event =
  Result.map_error
    (Printf.sprintf "%sevents[%d]: %s" where i)
    (expand_event places at (fields_of event))

let rec expand_events places ~where at i acc = function
  | [] -> Ok (List.rev acc)
  | event :: rest ->
      let* expanded = expand_nth places ~where at i event in
      let at = List.fold_left (fun a e -> reckon a (fields_of e)) at expanded in
      expand_events places ~where at (i + 1) (List.rev_append expanded acc) rest

let expand_checkpoint places ~source checkpoint events =
  let start =
    Option.bind (List.assoc_opt "start" checkpoint) observed_of_json
  in
  let where = source ^ ": checkpoint." in
  let* events = expand_events places ~where start 0 [] events in
  Ok (`Assoc (set "events" (`List events) checkpoint))

let expand places ~source json =
  let plan = fields_of json in
  let checkpoint = assoc "checkpoint" plan in
  match List.assoc_opt "events" checkpoint with
  | Some (`List events) ->
      let* checkpoint = expand_checkpoint places ~source checkpoint events in
      Ok (`Assoc (set "checkpoint" checkpoint plan))
  | _ -> Ok json
