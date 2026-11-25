open Json_field

let pos ~where obj = { Tile_pos.x = int ~where "x" obj; y = int ~where "y" obj }

let pair where : Yojson.Safe.t -> Tile_pos.t = function
  | `List [ `Int x; `Int y ] -> { x; y }
  | _ -> fail "%s is not [x, y]." where

let direction_named where name =
  match Direction.of_name name with
  | Some direction -> direction
  | None -> fail "%s \"%s\" is not north, east, south or west." where name

let direction ~where key obj =
  direction_named (where ^ key) (string ~where key obj)
