(* The place expansion with a made-up game: Town's door and a shop upstairs,
   reached by an elevator from Town's hall. *)

module R = Checkpoints_expand.Place_routes

let spot map x y facing : R.spot =
  { map; tile = { x; y }; facing = Grid_geometry.Direction.of_name facing }

let place = function
  | "door" -> Ok (spot "Town" 4 0 "north")
  | "shop" -> Ok (spot "Upstairs" 2 3 "west")
  | "landing" -> Ok (spot "Upstairs" 1 1 "south")
  | name -> Error ("no place " ^ name)

(* Upstairs only by the elevator from the hall's (1, 1). *)
let ride ~(at : R.spot) (target : R.spot) =
  if target.map = "Upstairs" && at.map <> "Upstairs" then
    Ok
      (Some
         {
           R.start = spot "Town" 1 1 "north";
           event =
             [ ("kind", `String "game_action"); ("action", `String "elevator") ];
           suffix = "ride";
           why = "up";
           arrival = spot "Upstairs" 1 1 "south";
         })
  else Ok None

(* Plans start on Town's (1, 1): the expansion reckons from the start. *)
let town = {|{"map": "Town", "tiles": [[1, 1]], "facing": "south"}|}

let expanded ?(start = town) =
  Expand_cases.expanded (R.expand { place; ride }) ~start

let route ?(extra = "") id name =
  Printf.sprintf
    {|{"id": "%s", "kind": "route", "args": {"target": {"place": "%s"}}%s}|} id
    name extra

let case = Expand_cases.case

let () =
  Table_test.run "place_routes"
    [
      case "a route to a place: its spot as the target"
        (expanded [ route "out" "door" ])
        {|{"id":"out","kind":"route","args":{"target":{"map":"Town","tiles":[[4,0]],"facing":"north"}}}|};
      case "a route with a map and tiles is left as it is"
        (expanded
           [
             {|{"id": "w", "kind": "route", "args": {"target": {"map": "Town", "tiles": [[2, 2]]}}}|};
           ])
        {|{"id":"w","kind":"route","args":{"target":{"map":"Town","tiles":[[2,2]]}}}|};
      case "a place that needs a ride: to it, the ride, the walk"
        (expanded
           [
             route "buy" "shop"
               ~extra:
                 {|, "skip_if": ["stocked"], "declared_after": {"map": "Upstairs", "tiles": [[2, 3]]}|};
           ])
        {|{"id":"buy","kind":"route","args":{"target":{"map":"Town","tiles":[[1,1]],"facing":"north"}},"skip_if":["stocked"],"why":"to where the ride starts, for shop"}
{"id":"buy.ride","kind":"game_action","action":"elevator","declared_after":{"map":"Upstairs","tiles":[[1,1]],"facing":"south"},"skip_if":["stocked"],"why":"up"}
{"id":"buy.walk","kind":"route","args":{"target":{"map":"Upstairs","tiles":[[2,3]],"facing":"west"}},"skip_if":["stocked"],"declared_after":{"map":"Upstairs","tiles":[[2,3]]}}|};
      case "a ride that lets the player out on the place: no walk"
        (expanded [ route "up" "landing" ])
        {|{"id":"up","kind":"route","args":{"target":{"map":"Town","tiles":[[1,1]],"facing":"north"}},"why":"to where the ride starts, for landing"}
{"id":"up.ride","kind":"game_action","action":"elevator","declared_after":{"map":"Upstairs","tiles":[[1,1]],"facing":"south"},"why":"up"}|};
      case "the position is reckoned along the plan: upstairs, no second ride"
        (expanded [ route "up" "landing"; route "buy" "shop" ])
        {|{"id":"up","kind":"route","args":{"target":{"map":"Town","tiles":[[1,1]],"facing":"north"}},"why":"to where the ride starts, for landing"}
{"id":"up.ride","kind":"game_action","action":"elevator","declared_after":{"map":"Upstairs","tiles":[[1,1]],"facing":"south"},"why":"up"}
{"id":"buy","kind":"route","args":{"target":{"map":"Upstairs","tiles":[[2,3]],"facing":"west"}}}|};
      case "the game's error names the event"
        (expanded [ route "x" "door"; route "y" "cellar" ])
        "t: checkpoint.events[1]: no place cellar";
      case "a place route with nowhere known to start from"
        (expanded ~start:{|{"map": "Town"}|} [ route "x" "door" ])
        "t: checkpoint.events[0]: where the player stands before it is not \
         known: give the checkpoint a start, or the event before it a one-tile \
         declared_after.";
      case "a declared_after reckons the position for the next place route"
        (expanded ~start:{|{"map": "Town"}|}
           [
             {|{"id": "fly", "kind": "game_action", "action": "fly", "declared_after": {"map": "Town", "tiles": [[3, 3]]}}|};
             route "out" "door";
           ])
        {|{"id":"fly","kind":"game_action","action":"fly","declared_after":{"map":"Town","tiles":[[3,3]]}}
{"id":"out","kind":"route","args":{"target":{"map":"Town","tiles":[[4,0]],"facing":"north"}}}|};
    ]
