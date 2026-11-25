type t = North | East | South | West

let all = [ North; East; South; West ]

let name = function
  | North -> "north"
  | East -> "east"
  | South -> "south"
  | West -> "west"

let of_name text = List.find_opt (fun d -> name d = text) all
let is_across = function East | West -> true | North | South -> false

let opposite = function
  | North -> South
  | East -> West
  | South -> North
  | West -> East
