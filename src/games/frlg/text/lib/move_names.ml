type t = (string * string) list

(* The same [<slug> <name>] lines as the species names file. *)
let of_string = Species_names.of_string
let load = Species_names.load
let name t slug = List.assoc_opt slug t
