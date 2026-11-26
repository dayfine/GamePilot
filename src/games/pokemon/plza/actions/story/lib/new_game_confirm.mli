(** 01.00b's first step: the new game's "Confirm Choices" screen, then "Ready!":
    ported from PokemonLZA_AutoStoryNewGame.cpp. The screen must read within 2 s
    (else [not_on_confirm_choices], which repeats: nothing was pressed); then,
    at most 6 times, A (held 160 ms, 2 s after) once "Ready!" is highlighted,
    else Down (160 ms, 500 after) and the highlight read again within 1 s;
    [confirm_not_ready] when it never reads on "Ready!".

    Where it differs: the name and language on the screen are not read (the fork
    checks the profile by OCR); the language, look and name are the user's, made
    by hand. *)

val run : Steps.game_steps -> Steps.outcome
(** "Ready!" confirmed, as above. *)
