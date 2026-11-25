(** What a Pokémon run keeps beside an event's save state, as
    [<n>-<event>.json], and its JSON: [start_money], [start_coins],
    [start_items] (what was read at the checkpoint's start) and [at] (where the
    player was reckoned to stand, or [null]). *)

open Pokemon_terms

type t = {
  start : Postcondition_check.start;
      (** What the run read at the checkpoint's start for the promises of a
          change. *)
  at : Pose.observed option;  (** Where the player was reckoned to stand. *)
}

include Engine_saved.Event_states.SAVED with type t := t

val observed_to_yojson : Pose.observed -> Yojson.Safe.t
(** [{"map": "CeladonCity", "tile": [48, 12], "facing": "south"}], the facing
    [null] when unknown. *)

val observed_of_yojson : Yojson.Safe.t -> (Pose.observed, string) result
(** What {!observed_to_yojson} wrote: ["not a map and a tile"] or
    ["not an object"] else. *)

val start_to_yojson : Postcondition_check.start -> (string * Yojson.Safe.t) list
(** [start_money], [start_coins] ([null] when not read) and [start_items] (an
    object of counts). *)

val start_of_yojson :
  (string * Yojson.Safe.t) list -> (Postcondition_check.start, string) result
(** What {!start_to_yojson} wrote. A file kept before the coins and items were
    (only [start_money]) reads with none of them read at the start, so their
    promises are not checked. *)
