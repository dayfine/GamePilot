(** A run straight ahead to a gate's A prompt: [run_to_gate] of
    PokemonLZA_AutoStoryConsoleActions.cpp over [run_towards_gate_with_A_button]
    of PokemonLZA_BasicNavigation.cpp ([plza/lean]), 03.07's run to Wild Zone
    1's gate. The stick ahead with B held, for up to [timeout_ms], until an A
    prompt shows: reached. When the party bar has been gone 400 ms (a day/night
    change stops the run, as the fork's [OverworldPartySelectionOverWatcher]
    reads it), it waits for free control ({!Free_control_wait}) and runs once
    more; then, or with no prompt in time, [gate_not_reached].

    Where it differs: the fork holds the stick in one press its watchers cut
    short; this holds it in 250 ms slices with a screen read after each, so it
    stops up to a slice later. The prompt counts on one read (the fork's watcher
    wants it 200 ms) and over the story screen's prompt box (0.3, 0.2, 0.4,
    0.65; the fork's is 0.7 high). The bar gone is the party bar
    ({!Walk_screen.t.player_can_move}: its D-pad marker or its empty last slot),
    where the fork reads the marker alone. *)

val run :
  Walk.game_steps -> timeout_ms:int -> (unit, Engine_run.Failure.cause) result
