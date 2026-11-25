(* The rules' zone, its JSON derived here: Plza_terms stays free of it. *)
type zone = Plza_terms.Pose.zone = { place : string; spot : string option }
[@@deriving yojson { strict = false }]

type t = { at : zone option } [@@deriving yojson { strict = false }]
