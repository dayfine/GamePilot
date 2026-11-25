open Pokemon_rules
open Own_kind

let list = String.concat ", "

let leg_text l =
  Printf.sprintf "%s %d" (Grid_geometry.Direction.name l.direction) l.tiles

let item_text i = Printf.sprintf "%d %s" i.quantity i.item
let fighting fight_wild = if fight_wild then " fighting" else ""
let pose = Pose_text.grid

let legs_text legs fight_wild =
  (if fight_wild then "legs fighting " else "legs ")
  ^ list (List.map leg_text legs)

let text = function
  | New_game -> "new_game"
  | Options -> "options"
  | Route { target; fight_wild } ->
      "route to " ^ pose target ^ fighting fight_wild
  | Ready target -> "ready at " ^ pose target
  | Legs { legs = l; fight_wild } -> legs_text l fight_wild
  | Step direction -> "step " ^ Grid_geometry.Direction.name direction
  | Battle { may_lose } -> if may_lose then "battle (may lose)" else "battle"
  | Train battles -> Printf.sprintf "train %d" battles
  | Heal -> "heal"
  | Shop items -> "shop " ^ list (List.map item_text items)
