(* The rules' pose, its JSON derived here: Toy_terms stays free of it. *)
type pose = Toy_terms.Pose.t = { place : string; spot : string option }
[@@deriving yojson]

type t = { start : int option; [@key "start_gold"] at : pose option }
[@@deriving yojson]
