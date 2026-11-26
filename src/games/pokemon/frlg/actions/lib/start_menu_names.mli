(** Which Start menu is open, by its names: each row's text read with the game's
    font ({!Frlg_text.Text_lines.start_menu_row}), so an action finds its row by
    name rather than counting rows (the menu grows during the story and the
    Safari Zone's starts with RETIRE) and never presses A on a row it did not
    read. GamePilot's own: the fork's StartMenuNavigation moves to a row by
    position.

    Language: Start menu row labels are matched as English text; non-English
    ROMs need localized candidate strings. *)

val names : string list
(** The candidates: POKéDEX, POKéMON, BAG, SAVE, OPTION, EXIT, RETIRE. The
    player's own name is none of them and reads as no row. *)

val read_rows : unit -> string option list
(** The seven rows' names, top first; [None] for a row that reads as none (the
    player's name, a row below a short menu). With the Start menu open. *)

val row_of : string -> string option list -> int option
(** The first row reading that name, from 0. *)
