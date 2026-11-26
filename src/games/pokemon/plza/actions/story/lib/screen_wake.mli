(** Wakes a dimmed screen before anything is read from it: the right stick up
    100 ms, then down 100 ms, then 500 ms for the dim to lift
    ({!Switch_home.Stick_wake}). Ours: the fork runs its programs with the
    console awake. The Switch dims its screen after a while with no input; a
    dimmed frame reads as nothing (console B, 2026-11-25: 01.03's run 2 started
    on Urbain's heal dialog, dimmed after a long idle with keep-awake off, so
    the resume check saw no dialog and the walk ran). The right stick moves the
    camera in the field and does nothing in a dialogue, a choice, a card, a menu
    or a battle's HUD, so it is safe in every PLZA state, unlike a button (B
    backs out of the new game's menus, A answers). Up then down, not sideways:
    the camera's pitch comes back and its heading never moves, so the walk legs
    after it, aimed from where the camera looks, keep their aim (02.01's run 1:
    a sideways nudge turned the camera right, and the first leg ran into the
    alley's crates). *)

val run : Steps.game_steps -> unit
(** The stick up, down and the wait, as above. *)
