open Pokemon_terms

let observed_to_yojson (p : Pose.observed) =
  `Assoc
    [
      ("map", `String p.at_map);
      ("tile", `List [ `Int p.at_tile.x; `Int p.at_tile.y ]);
      ( "facing",
        match p.faces with
        | Some d -> `String (Grid_geometry.Direction.name d)
        | None -> `Null );
    ]

let facing_of = function
  | `String name -> Grid_geometry.Direction.of_name name
  | _ -> None

let observed_of_yojson = function
  | `Assoc f -> (
      match (List.assoc_opt "map" f, List.assoc_opt "tile" f) with
      | Some (`String at_map), Some (`List [ `Int x; `Int y ]) ->
          let faces = Option.bind (List.assoc_opt "facing" f) facing_of in
          Ok { Pose.at_map; at_tile = { x; y }; faces }
      | _ -> Error "not a map and a tile")
  | _ -> Error "not an object"

let option_json f = function Some v -> f v | None -> `Null
let int_json n = `Int n

let start_to_yojson (start : Postcondition_check.start) =
  [
    ("start_money", option_json int_json start.start_money);
    ("start_coins", option_json int_json start.start_coins);
    ( "start_items",
      `Assoc (List.map (fun (i, n) -> (i, int_json n)) start.start_items) );
  ]

let count_of_json name = function
  | `Int n -> Ok (Some n)
  | `Null -> Ok None
  | _ -> Error (name ^ " is not a number")

let field fields name = Option.value (List.assoc_opt name fields) ~default:`Null
let ( let* ) = Result.bind

let rec items_read = function
  | [] -> Ok []
  | (item, `Int n) :: rest ->
      let* rest = items_read rest in
      Ok ((item, n) :: rest)
  | (item, _) :: _ -> Error ("start_items: " ^ item ^ " is not a number")

(* Each item's count at the start; none in a file kept before items were. *)
let items_of_json = function
  | `Null -> Ok []
  | `Assoc items -> items_read items
  | _ -> Error "start_items is not an object"

let start_of_yojson fields =
  let count name = count_of_json name (field fields name) in
  let* start_money = count "start_money" in
  let* start_coins = count "start_coins" in
  let* start_items = items_of_json (field fields "start_items") in
  Ok { Postcondition_check.start_money; start_coins; start_items }

type t = { start : Postcondition_check.start; at : Pose.observed option }

let to_yojson { start; at } =
  `Assoc
    (start_to_yojson start
    @ [ ("at", Option.fold ~none:`Null ~some:observed_to_yojson at) ])

let at_of_yojson = function
  | `Null -> Ok None
  | json ->
      Result.map_error (fun e -> "at: " ^ e) (observed_of_yojson json)
      |> Result.map Option.some

let of_yojson = function
  | `Assoc fields ->
      let* start = start_of_yojson fields in
      let* at =
        at_of_yojson (Option.value (List.assoc_opt "at" fields) ~default:`Null)
      in
      Ok { start; at }
  | _ -> Error "what is kept is not an object"
