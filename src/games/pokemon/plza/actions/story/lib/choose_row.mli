(** A dialogue choice's row taken: [choose_row] of
    PokemonLZA_AutoStoryScenes.cpp ([plza/lean]), the plan's [choose_0] and
    [choose_1]. Waits up to 3 s (a read every 250 ms) for a choice box whose
    rows read; without one, A through the question's text (held 160 ms, released
    240) and waits again, three times at most ([no_choice]). A row past the last
    fails ([no_such_choice]). Down or Up from the highlighted row to the row,
    each held 160 ms, released 240; after a move, one read must show the row
    highlighted ([choice_not_reached]); then A. *)

val run : Story_steps.game_steps -> int -> Story_steps.outcome
(** [run steps index]: row [index] (0 the top) taken. *)
