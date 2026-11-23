(** Reader: the menu a party member opens over the party (SUMMARY, its field
    moves, SWITCH, ITEM or MAIL, CANCEL) and its selection arrow. Not in the
    fork. The window's bottom stays put and it grows upward with each field move
    the member knows, so the probes find its rows from the bottom. Measured on
    mGBA frames; the boxes are game pixels, so a Switch capture's picture reads
    the same if its scale holds. The arrow is found as in {!Cursor_column},
    among the rows the window's white inside reaches. *)

val probes : Wire.probe_spec list

val cursor : Cursor_column.t
(** Eight row boxes from the bottom: the four rows every member has and up to
    four field moves. *)

val min_rows : int
(** The menu shows when its white inside reaches at least this many rows from
    the bottom: 4. *)

val rows : Effects.measurements -> int option
(** The menu's rows while it shows (4 plus one per field move); [None] when it
    does not. *)

val cursor_row : Effects.measurements -> int option
(** The arrow's row from 0 at the top (SUMMARY) while the menu shows; [None]
    when it does not. *)

val summary_row : int
(** SUMMARY's row: 0, above the field moves. *)

val switch_row : rows:int -> int
(** SWITCH's row in a menu of [rows]: third from the bottom, above ITEM (or
    MAIL) and CANCEL. *)
