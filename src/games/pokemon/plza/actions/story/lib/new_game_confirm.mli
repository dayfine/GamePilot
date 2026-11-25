(** 01.00b's first step: the new game's "Confirm Choices" screen, then "Ready!":
    [require_confirm_choices] and [confirm_new_game_choices] of
    PokemonLZA_AutoStoryNewGame.cpp ([plza/lean]). The screen must read within 2
    s (else [not_on_confirm_choices], which repeats: nothing was pressed); then,
    at most 6 times, A (held 160 ms, 2 s after) once "Ready!" is highlighted,
    else Down (160 ms, 500 after) and the highlight read again within 1 s;
    [confirm_not_ready] when it never reads on "Ready!".

    Where it differs: the name and language on the screen are not read (the
    fork's OCR [check_profile]); the language, look and name are the user's,
    made by hand. *)

val run : Story_steps.game_steps -> Story_steps.outcome
