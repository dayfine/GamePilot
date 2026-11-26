(** The Pokémon moved into the gifts' empty slots in Box 1, from party slot 6
    and from the box the Boxes opened on, as {!Gift_boxes} says, the cursor and
    the box as {!Box_cursor} and {!Box_paging} keep them. Ours: the fork has no
    Mystery Gift program. *)

val party_six : int * int
(** Party slot 6's row and column. *)

val title_row : int
(** The row the cursor waits on while L or R changes the box: 2, off the first
    row, whose name tag covers the box title. *)

val fill :
  log:(string -> unit) ->
  Box_cursor.t ->
  Box_paging.t ->
  in_party:bool ->
  Plza_gift_catalog.Gift_catalog.box_slot list ->
  (int, string) result
(** On Box 1, the empty gift slots given (in the order their gifts were
    received) filled: the first from party slot 6 when [in_party], the next from
    the box the Boxes opened on when it holds as many Pokémon as slots left;
    back on Box 1. The number of Pokémon moved; [Error] when a box title does
    not read, or a Pokémon carried to party slot 6 could not go on to its slot.
*)
