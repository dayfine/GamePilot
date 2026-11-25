type leg = { direction : Grid_geometry.Direction.t; tiles : int }
type item = { item : string; quantity : int }
type route = { target : Pose.grid; fight_wild : bool; fight_trainers : bool }

type t =
  | New_game
  | Options
  | Route of route
  | Ready of Pose.grid
  | Legs of { legs : leg list; fight_wild : bool }
  | Step of Grid_geometry.Direction.t
  | Battle of { may_lose : bool }
  | Train of int
  | Heal
  | Shop of item list
