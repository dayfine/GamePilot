type t = Range of { min : int; max : int } | Spent of int

let text = function
  | Range { min; max } -> Printf.sprintf "money %d to %d" min max
  | Spent n -> Printf.sprintf "money spent %d" n
