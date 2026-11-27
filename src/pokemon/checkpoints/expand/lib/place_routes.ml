open Engine_expand
open Grid_geometry
module J = Plan_json

type spot = { map : string; tile : Tile_pos.t; facing : Direction.t option }

type ride = {
  start : spot;
  event : J.fields;
  suffix : string;
  why : string;
  arrival : spot;
}

type game = {
  place : string -> (spot, string) result;
  ride : at:spot -> spot -> (ride option, string) result;
}

let ( let* ) = Result.bind

let spot_json s : Yojson.Safe.t =
  let facing =
    Option.fold ~none:[]
      ~some:(fun d -> [ ("facing", `String (Direction.name d)) ])
      s.facing
  in
  `Assoc
    ([
       ("map", `String s.map);
       ("tiles", `List [ `List [ `Int s.tile.x; `Int s.tile.y ] ]);
     ]
    @ facing)

let one_tile = function
  | Some (`List [ `List [ `Int x; `Int y ] ]) -> Some { Tile_pos.x; y }
  | _ -> None

(* A one-tile pose's JSON as a spot. *)
let spot_of json =
  let f = J.fields_of json in
  match (J.string_field "map" f, one_tile (List.assoc_opt "tiles" f)) with
  | Some map, Some tile ->
      Some
        {
          map;
          tile;
          facing = Option.bind (J.string_field "facing" f) Direction.of_name;
        }
  | _ -> None

(* Where the player stands after the event, as the runner reckons it. *)
let reckon at event =
  let target = List.assoc_opt "target" (J.object_field "args" event) in
  let routed =
    if J.string_field "kind" event = Some "route" then
      Option.bind target spot_of
    else None
  in
  match routed with
  | Some _ -> routed
  | None -> (
      match Option.bind (List.assoc_opt "declared_after" event) spot_of with
      | Some _ as declared -> declared
      | None -> at)

(* The place a route event names as its target, if it names one. *)
let place_name event =
  let target = J.object_field "target" (J.object_field "args" event) in
  match (J.string_field "kind" event, List.assoc_opt "place" target) with
  | Some "route", Some (`String name) -> Some (Ok name)
  | Some "route", Some _ -> Some (Error "target.place is not a string.")
  | _ -> None

let route_to s event =
  J.set "args"
    (`Assoc (J.set "target" (spot_json s) (J.object_field "args" event)))
    event

(* The spot is the target's, the facing too when both know it. *)
let arrives_at target s =
  s.map = target.map
  && Tile_pos.equal s.tile target.tile
  && (s.facing = None || target.facing = None || s.facing = target.facing)

let ride_event id event (r : ride) =
  let skip = List.filter (fun (k, _) -> k = "skip_if") event in
  `Assoc
    ((("id", `String (id ^ "." ^ r.suffix)) :: r.event)
    @ [ ("declared_after", spot_json r.arrival) ]
    @ skip
    @ [ ("why", `String r.why) ])

let with_ride ~id ~name event target (r : ride) =
  let why = Printf.sprintf "to where the ride starts, for %s" name in
  let to_start =
    route_to r.start event |> J.without "declared_after"
    |> J.set "why" (`String why)
  in
  let walk = route_to target event |> J.set "id" (`String (id ^ ".walk")) in
  [ `Assoc to_start; ride_event id event r ]
  @ if arrives_at target r.arrival then [] else [ `Assoc walk ]

let unknown_start =
  "where the player stands before it is not known: give the checkpoint a \
   start, or the event before it a one-tile declared_after."

let to_place game at event name =
  let* target = game.place name in
  let* at = Option.to_result ~none:unknown_start at in
  let* ride = game.ride ~at target in
  let id = Option.value ~default:"" (J.string_field "id" event) in
  match ride with
  | None -> Ok [ `Assoc (route_to target event) ]
  | Some r -> Ok (with_ride ~id ~name event target r)

let expand_declared_after game event =
  match List.assoc_opt "declared_after" event with
  | Some (`Assoc fields) -> (
      match List.assoc_opt "place" fields with
      | Some (`String name) ->
          let* spot = game.place name in
          Ok (J.set "declared_after" (spot_json spot) event)
      | Some _ -> Error "declared_after.place is not a string."
      | None -> Ok event)
  | _ -> Ok event

let step game at event =
  let* event = expand_declared_after game event in
  let* events =
    match place_name event with
    | None -> Ok [ `Assoc event ]
    | Some name -> Result.bind name (to_place game at event)
  in
  Ok (events, List.fold_left (fun a e -> reckon a (J.fields_of e)) at events)

let expand game ~source json =
  J.rewrite_events ~source
    ~start:(fun checkpoint ->
      Option.bind (List.assoc_opt "start" checkpoint) spot_of)
    ~step:(step game) json
