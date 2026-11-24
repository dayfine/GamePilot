(** What the checkpoint runner does around a run on a console, where there are
    no save states (the Switch): the game's own save is the start. Before each
    run it returns to the last save and checks the start; after it, a run that
    passed, its end checks included, is saved in the game (when the series saves
    after a pass) and its end kept as the next start's frame; a run that failed
    returns to the last save, so the console is left at the checkpoint's start
    for a rerun once the code is fixed; a run stopped from the watch page is
    left where it stopped. A failed or stopped run never saves.

    The fork's AutoStory on the console does the same per checkpoint: its
    [frlg_save_policy] saves after a passing checkpoint and its
    [StoryGame::reload] reloads the save after a failure
    (PokemonFRLG_AutoStory.cpp, [frlg/lean]). *)

type outcome =
  | Passed
  | Failed_event  (** An event failed. *)
  | Failed_end_check
      (** Every event passed, but the end position or a postcondition did not.
      *)
  | Stopped  (** Stop was pressed on the watch page. *)

type step =
  | Return_to_save  (** Soft reset to the last save. *)
  | Save_in_game
  | Keep_start_frame  (** The frame now, as the next checkpoint's start. *)

val before_run : step list
(** [Return_to_save]: the start check follows it. *)

val after_run : save_after_pass:bool -> outcome -> step list

val outcome_of_failure : Failure.reason -> outcome
(** [Not_at_end] and [Unmet_postconditions] are end checks; the rest, events. *)

val step_name : step -> string
val outcome_name : outcome -> string
