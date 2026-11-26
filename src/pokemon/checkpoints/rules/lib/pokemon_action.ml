type leg = { direction : Grid_geometry.Direction.t; tiles : int }
type item = { item : string; quantity : int }
type route = { target : Pose.grid; fight_wild : bool; fight_trainers : bool }

type t =
  | New_game
  | Game_settings
  | Route of route
  | Ready of Pose.grid
  | Legs of { legs : leg list; fight_wild : bool }
  | Step of Grid_geometry.Direction.t
  | Battle of { may_lose : bool }
  | Train of int
  | Heal
  | Shop of item list

let list = String.concat ", "

let leg_text l =
  Printf.sprintf "%s %d" (Grid_geometry.Direction.name l.direction) l.tiles

let item_text i = Printf.sprintf "%d %s" i.quantity i.item
let fighting fight_wild = if fight_wild then " fighting" else ""
let pose = Pose.grid_to_string

let legs_text legs fight_wild =
  (if fight_wild then "legs fighting " else "legs ")
  ^ list (List.map leg_text legs)

let to_string = function
  | New_game -> "new_game"
  | Game_settings -> "game_settings"
  | Route { target; fight_wild; fight_trainers } ->
      "route to " ^ pose target ^ fighting fight_wild
      ^ if fight_trainers then " fighting trainers" else ""
  | Ready target -> "ready at " ^ pose target
  | Legs { legs = l; fight_wild } -> legs_text l fight_wild
  | Step direction -> "step " ^ Grid_geometry.Direction.name direction
  | Battle { may_lose } -> if may_lose then "battle (may lose)" else "battle"
  | Train battles -> Printf.sprintf "train %d" battles
  | Heal -> "heal"
  | Shop items -> "shop " ^ list (List.map item_text items)
