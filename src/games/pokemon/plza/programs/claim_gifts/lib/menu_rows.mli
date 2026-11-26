(** Moving the main menu's cursor to a row (console B, 2026-11-20): the
    highlighted row is read ({!Plza_readers.Main_menu_row}), then the shorter
    way round the six rows is pressed (Down or Up, 80 ms, released 300); the row
    is read again after the moves, and a row other than the target is an error,
    as is no menu at all. The menu's probes must be subscribed
    ({!Plza_readers.Main_menu_row.probes}). Ours: the fork's PLZA programs have
    no Mystery Gift. *)

val read_row : unit -> int option
(** The highlighted row, read within 1.5 s; [None] when the main menu does not
    show. *)

val open_menu : log:(string -> unit) -> (int, string) result
(** From the overworld: X (100 ms, released 1500), then the highlighted row; no
    X when the menu already shows. [Error] when no menu shows. *)

val goto : log:(string -> unit) -> int -> (unit, string) result
(** From the open menu to row [target] (0 the top). *)
