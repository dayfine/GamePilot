(** What a Pokémon run keeps beside an event's save state, as
    [<n>-<event>.json], and its JSON, derived ([[@@deriving yojson]]):
    [start_money] and [start_coins] (a number or [null]), [start_items] (an
    object of counts) and [at] ({!observed_to_yojson}, or [null]). A field left
    out reads as not read: a file kept before the coins and items were has only
    [start_money] and [at]. The JSON is derived here, on a copy of the rules'
    types, so {!Pokemon_rules} links no JSON. *)

open Pokemon_rules

type t = {
  start : Postcondition_check.start;
      (** What the run read at the checkpoint's start for the promises of a
          change. *)
  at : Pose.observed option;  (** Where the player was reckoned to stand. *)
}

include Engine_event_snapshot.Event_snapshot.SNAPSHOT with type t := t

val observed_to_yojson : Pose.observed -> Yojson.Safe.t
(** [{"map": "CeladonCity", "tile": [48, 12], "facing": "south"}], the facing
    [null] when unknown. *)

val observed_of_yojson : Yojson.Safe.t -> (Pose.observed, string) result
(** What {!observed_to_yojson} wrote; an error names the type or the missing
    field (["Pokemon_event_snapshot.observed.at_map"]), a tile not [[x, y]] is
    ["tile: not [x, y]"], and a facing it cannot read is unknown. *)
