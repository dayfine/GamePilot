(** Wakes a dimmed screen before anything is read from it: the right stick
    tilted right 100 ms, then 500 ms for the dim to lift. Ours: the fork runs
    its programs with the console awake. The Switch dims its screen after a
    while with no input; a dimmed frame reads as nothing (console B, 2026-11-25:
    01.03's run 2 started on Urbain's heal dialog, dimmed after a long idle with
    keep-awake off, so the resume check saw no dialog and the walk ran). The
    right stick turns the camera in the field and does nothing in a dialogue, a
    choice, a card, a menu or a battle's HUD, so it is safe in every PLZA state,
    unlike a button (B backs out of the new game's menus, A answers). *)

val run : Story_steps.game_steps -> unit
