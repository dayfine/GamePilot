(** A member's moves read off the summary's moves page by their names
    ({!Frlg_text.Line_reading}, every English move name a candidate), and the
    move offered on the list a battle opens to forget a move from, which is the
    same page with a fifth row (pokefirered pokemon_summary_screen.c,
    PrintMovesPage). Moves are slugs (["recycle"]). *)

val moves_page : int
(** 3. *)

val read_row : int -> string option
(** Row [i] (0-4) of the open moves page; [None] for a row that shows no move
    name (an empty slot, another screen). *)

val read_offered : unit -> string option
(** {!read_row} 4: the move offered on the list to forget from. *)

val open_summary : int -> unit
(** From the overworld: the party, the member in this slot (from 1), SUMMARY on
    its menu, until the info page (1) shows. In {!Frlg_readers.Summary_screen}'s
    probes. Fails as [no_party], [no_member_menu] or [no_summary]. *)

val on_page : int -> Effects.measurements -> bool
(** The summary shows this page. *)

val page_turn_ms : int
(** Between two RIGHT presses on the summary: 700 ms. *)

val settled_rows : unit -> string list
(** The open moves page's known moves once its rows settled (see {!read_known}).
    Fails as [no_summary]. *)

val read_known : log:(string -> unit) -> slot:int -> string list

val reread_ms : int
(** Between two reads of the moves page's rows: 150 ms. *)

val max_reads : int
(** Reads of the rows before they must have settled: 12. *)

(** From the overworld: the party, the member in [slot] (from 1), SUMMARY on its
    menu ({!Menu_cursor}), RIGHT to the moves page, its four rows read until the
    first shows a move and two reads {!reread_ms} apart agree (the page's mark
    turns before the names are drawn), then B back to the overworld. Fails as
    [no_party], [no_member_menu] or [no_summary]. *)
