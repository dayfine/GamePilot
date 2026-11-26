(** Moves a menu's cursor by reading where it is, never by counting presses:
    FireRed keeps the Start menu's row and the party's slot from the last time
    they were open (a save state keeps them too), and a tap the game is not yet
    taking (a menu still sliding or fading in) is lost. So each step reads the
    row, taps once toward the target, and waits for the read row to change; a
    tap that changed nothing is tapped again. A is pressed only when the target
    reads selected, and again while the screen it opens does not show. Menus
    with no cursor reader (a bag item's own menu, a Mart's list, the Game
    Corner's choices, the fly map) still count their presses where they are
    pressed. *)

type column
(** A menu's rows and the reader of the selected one; DOWN moves to a higher
    row. *)

val start_menu : column
(** {!Frlg_readers.Start_menu.cursor_row}: rows from 0 at the top. *)

val party : column
(** {!Frlg_readers.Party_menu.selected_slot}: slots from 1. *)

val member_menu : column
(** {!Frlg_readers.Member_menu.cursor_row}: rows from 0 (SUMMARY). *)

val confirm_ms : int
(** Between the A (or START) presses of {!choose} and {!open_start_menu_row}
    while the next screen does not show: 1000 ms. *)

val max_confirms : int
(** Those presses at most: 3. *)

val move_to : code:string -> column -> int -> unit
(** Taps until the menu reads the cursor on this row. Fails as [code] when the
    menu does not show or the cursor stays off the row. *)

val choose :
  code:string -> column -> int -> taken:(Effects.measurements -> bool) -> unit
(** {!move_to}, then A until [taken] holds (the screen the row opens). Fails as
    [code]. *)

val open_start_menu : unit -> unit
(** START until the Start menu shows. Fails as [no_start_menu]. *)

val start_menu_taken : Effects.measurements -> bool
(** The menu closed, or a text box shows: the row's A was taken. *)

val open_start_menu_row : int -> unit
(** START until the Start menu shows, then {!choose} the row (from 0 at the top)
    until the menu closes or a text box shows. Fails as [no_start_menu]. *)
