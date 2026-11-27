(** What a BDSP run keeps beside an event's state
    ({!Engine_event_snapshot.Event_snapshot.SNAPSHOT}): the zone pose where the
    player was reckoned to stand, if any. *)

type t = {
  at : Engine_event_snapshot.Zone_snapshot.t option;
      (** Where the player was reckoned to stand, if known. *)
}
(** What a run keeps beside an event's state. *)

val to_yojson : t -> Yojson.Safe.t
(** Encodes the kept snapshot as JSON. *)

val of_yojson : Yojson.Safe.t -> (t, string) result
(** Decodes a snapshot written by {!to_yojson}. *)
