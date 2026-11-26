(** What plza.bank-home moves: each Pokémon gift of PLZA's gift catalog
    ({!Plza_gift_catalog.Gift_catalog}), from its slot in the game's Box 1 to
    the first empty slot of its HOME boxes, in the catalog's order
    ({!Pokemon_home.Box_moves.t}). The catalog is the one place a gift's box
    slot and HOME boxes are written; plza.claim-gifts leaves each gift in that
    slot. Items-only gifts are not moved. *)

val of_catalog :
  Plza_gift_catalog.Gift_catalog.t ->
  (Pokemon_home.Box_moves.t list, string) result
(** The moves, named by each gift's name for log lines; [Error] when a gift's
    slot is not in Box 1's first row (slots 1 to 6, where a move starts), or no
    gift has a Pokémon. *)
