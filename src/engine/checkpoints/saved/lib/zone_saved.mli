(** A zone pose's JSON in what a run keeps ({!Kept}'s [at]):
    [{"place": "Forest", "spot": null}], derived ([[@@deriving yojson]]) here so
    {!Engine_rules.Zone_pose} stays free of JSON. *)

type t = Engine_rules.Zone_pose.t = { place : string; spot : string option }

val to_yojson : t -> Yojson.Safe.t
val of_yojson : Yojson.Safe.t -> (t, string) result
