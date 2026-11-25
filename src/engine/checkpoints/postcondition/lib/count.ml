type t = Exactly of int | Gained of int | At_least of int

let text = function
  | Exactly n -> Printf.sprintf "x%d" n
  | Gained n when n < 0 -> Printf.sprintf "used %d" (-n)
  | Gained n -> Printf.sprintf "gained %d" n
  | At_least n -> Printf.sprintf "at least %d" n
