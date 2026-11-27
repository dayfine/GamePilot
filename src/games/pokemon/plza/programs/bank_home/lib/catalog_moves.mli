(** What pokemon_home.bank-plza moves: each Pokémon gift of PLZA's gift catalog
    ({!Plza_gift_catalog.Gift_catalog}) that has not expired, from its slot in
    the game's Box 1 to the first empty slot of its HOME boxes, in the catalog's
    order ({!Pokemon_home.Box_moves.t}). The catalog is the one place a gift's
    box slot and HOME boxes are written; plza.claim-gifts leaves each gift in
    that slot. Items-only gifts are not moved.

    A gift whose last day is before the run's day is skipped, as claim-gifts
    skips it ({!Plza_gift_catalog.Gift_catalog.expired}, the same rule and day):
    its slot is empty on a save claimed after that day. Any other gift is moved,
    so a gift claim-gifts failed for another reason fails the bank at its empty
    slot instead of being left out unseen. *)

type t = {
  moves : Pokemon_home.Box_moves.t list;
      (** The moves, named by each gift's name for log lines. *)
  skipped : string list;
      (** A log line for each expired gift left out
          ({!Plza_gift_catalog.Gift_catalog.skipped_line}). *)
}
(** One run's moves. *)

val of_catalog :
  today:Plza_gift_catalog.Gift_catalog.date ->
  Plza_gift_catalog.Gift_catalog.t ->
  (t, string) result
(** The moves on [today] (the host's day, UTC, as claim-gifts gets it); [Error]
    when a gift's slot is not in Box 1 (slots 1 to 30), no gift has a Pokémon,
    or every one has expired. *)
