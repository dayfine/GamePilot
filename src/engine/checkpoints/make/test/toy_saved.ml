(* The rules' pose, its JSON derived here: Toy_rules stays free of it. *)
type pose = Toy_rules.Pose.t = { place : string; spot : string option }
[@@deriving yojson]

type t = { start : int option; [@key "start_gold"] at : pose option }
[@@deriving yojson]
