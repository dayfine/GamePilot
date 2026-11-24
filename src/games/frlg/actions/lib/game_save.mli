(** The in-game save from the overworld: START, SAVE, then each screen after the
    first YES/NO as {!Save_dialog} says until the overworld is back, saved.
    Ported from the fork's [save_game()] and [run_save_dialog()]
    (AutoStory/PokemonFRLG_AutoStoryActions.cpp, [frlg/lean]) with its timings;
    its [overworld_shows()] confirms the end (START opens the menu, B closes
    it).

    Where it differs: the save card's place is not read (no OCR here; the fork's
    [SavePlaceCheck]): the runner's start check after the next reload compares
    the place instead ({!Frlg_readers.Start_frame}). *)

val yes_no_timeout_ms : int
(** 5 s for the first YES/NO after SAVE. *)

val save_timeout_ms : int
(** 30 s from it to the overworld: the fork's [SAVE_TIMEOUT]. *)

val poll_ms : int
(** 300 ms between looks: the fork's [POLL]. *)

val classify : Effects.measurements -> Save_dialog.screen
(** The fork's [read_save_screen()]: the YES/NO first, then the Start menu (it
    can show a help box under it), a page with the arrow, a text box. *)

val save : log:(string -> unit) -> unit -> unit
(** SAVE is found by its name on the menu ({!Start_menu_names}), never by its
    row; each A after it is pressed on a screen just read: YES only on a YES/NO,
    the next page only on a page with its arrow. Raises
    {!Menu_input.Action_failed}: [no_start_menu], [save_not_on_menu],
    [save_no_question], [save_cancelled], [save_error] or [save_timeout]. *)

val save_game :
  log:(string -> unit) -> unit -> (unit, Story.Failure.cause) result
(** {!save} under {!Menu_input.run} with the YES/NO probes subscribed. *)
