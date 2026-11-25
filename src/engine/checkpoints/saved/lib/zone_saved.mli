(** A zone pose's JSON in what a run keeps ({!Kept}'s [at]):
    [{"place": "Forest", "spot": null}], derived ([[@@deriving yojson]]) here so
    {!Engine_rules.Zone_pose} stays free of JSON. *)

type t = Engine_rules.Zone_pose.t = { place : string; spot : string option }
(** The zone, re-exported so the deriver sees its fields. *)

val to_yojson : t -> Yojson.Safe.t
(** The zone as a JSON object. *)

val of_yojson : Yojson.Safe.t -> (t, string) result
(** What {!to_yojson} wrote, or why it cannot be read. *)
