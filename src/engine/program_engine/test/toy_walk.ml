(* The toy's walk set: hold a direction until a landmark shows. *)

type t = { toward : string; until : string }

let to_string { toward; until } = Printf.sprintf "walk %s until %s" toward until
