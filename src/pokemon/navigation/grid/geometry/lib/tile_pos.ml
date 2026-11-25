type t = { x : int; y : int }

let next { x; y } (direction : Direction.t) =
  match direction with
  | North -> { x; y = y - 1 }
  | East -> { x = x + 1; y }
  | South -> { x; y = y + 1 }
  | West -> { x = x - 1; y }

let to_string { x; y } = Printf.sprintf "(%d, %d)" x y
let compare (a : t) (b : t) = compare (a.x, a.y) (b.x, b.y)
let equal (a : t) (b : t) = a.x = b.x && a.y = b.y
