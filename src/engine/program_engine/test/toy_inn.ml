(* The toy's inn set: rest, and buy an item. *)

type t = Rest | Buy of string

let to_string = function Rest -> "rest" | Buy item -> "buy " ^ item
