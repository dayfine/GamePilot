(** Reader: the red cursor box on the summary screen's move list while a move is
    being picked: the list that opens after YES to "Delete a move to make room
    for ...?" (in a battle or from a TM), whose fifth row is the move to learn,
    and A on KNOWN MOVES. Ported from the fork's read_summary_move_cursor
    (Menus/PokemonFRLG_SummaryMovesReader): the box's left edge, (255, 72, 0) at
    x 120-121, one [core.color_count@1] probe per row (y 24-40 on the top row,
    rows 28 apart), in game pixels. *)

val rows : int
(** 5: four known moves and the one to learn. *)

val probes : Wire.probe_spec list

(** {1 Thresholds} *)

val min_red_share : float
(** The edge's red ((201, 0, 0) to (255, 139, 89): the fork's r > 200, g < 140,
    b < 90) covers more than this share of a row's box (the fork's half): the
    box is drawn there and nowhere else. *)

(** {1 Reader} *)

val row : Effects.measurements -> int option
(** The cursor's row from 0 at the top; [None] when no row or more than one has
    the edge (no move being picked). *)
