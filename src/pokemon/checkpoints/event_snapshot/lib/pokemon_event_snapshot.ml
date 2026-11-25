open Grid_geometry
open Pokemon_rules

(* A tile is kept as [[x, y]], a facing by its name; a facing the run cannot
   read back is unknown, as when the game could not tell. *)
let tile_to_json (t : Tile_pos.t) = `List [ `Int t.x; `Int t.y ]

let tile_of_json : Yojson.Safe.t -> (Tile_pos.t, string) result = function
  | `List [ `Int x; `Int y ] -> Ok { x; y }
  | _ -> Error "tile: not [x, y]"

let facing_to_json = function
  | Some d -> `String (Direction.name d)
  | None -> `Null

let facing_of_json = function
  | `String name -> Ok (Direction.of_name name)
  | _ -> Ok None

(* The rules' type, its JSON derived here: Pokemon_rules stays free of it. *)
type observed = Pose.observed = {
  at_map : string; [@key "map"]
  at_tile : Tile_pos.t;
      [@key "tile"] [@to_yojson tile_to_json] [@of_yojson tile_of_json]
  faces : Direction.t option;
      [@key "facing"] [@to_yojson facing_to_json] [@of_yojson facing_of_json]
}
[@@deriving yojson { strict = false }]

type t = { start : Postcondition_check.start; at : Pose.observed option }

let items_to_yojson items = `Assoc (List.map (fun (i, n) -> (i, `Int n)) items)
let ( let* ) = Result.bind

let rec items_read = function
  | [] -> Ok []
  | (item, `Int n) :: rest ->
      let* rest = items_read rest in
      Ok ((item, n) :: rest)
  | (item, _) :: _ -> Error ("start_items: " ^ item ^ " is not a number")

let items_of_yojson = function
  | `Assoc items -> items_read items
  | _ -> Error "start_items is not an object"

(* The file: the counts read at the start beside the pose, in one object
   (each item's count an object of counts). [t] nests the counts under
   [start] and the file keeps them flat, so the file is its own record. *)
type file = {
  start_money : int option;
  start_coins : int option;
  start_caught : int option;
  start_items : (string * int) list;
      [@to_yojson items_to_yojson] [@of_yojson items_of_yojson]
  at : observed option;
}
[@@deriving yojson { strict = false }]

let to_yojson
    { start = { start_money; start_coins; start_caught; start_items }; at } =
  file_to_yojson { start_money; start_coins; start_caught; start_items; at }

(* A field left out reads as not read: a file kept before the coins and
   items were has only [start_money] and [at]. [@default] would read it too,
   but would also leave the unread fields out of every file written. *)
let unread =
  [
    ("start_money", `Null);
    ("start_coins", `Null);
    ("start_caught", `Null);
    ("start_items", `Assoc []);
    ("at", `Null);
  ]

let with_unread fields =
  fields
  @ List.filter (fun (name, _) -> not (List.mem_assoc name fields)) unread

let of_file { start_money; start_coins; start_caught; start_items; at } =
  { start = { start_money; start_coins; start_caught; start_items }; at }

let of_yojson = function
  | `Assoc fields ->
      Result.map of_file (file_of_yojson (`Assoc (with_unread fields)))
  | _ -> Error "what is kept is not an object"
