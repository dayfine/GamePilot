(** A story scene pressed through to its end: [run_scene_machine] of
    PokemonLZA_AutoStorySceneMachine.cpp ([plza/lean]) with the config 01.01's
    scenes use (A, and maybe [end_on_black_fade]), its classes, presses and
    timings. Each read every 250 ms is classed: a fade waits (or, with
    [end_on_black_fade], a black fade ends it); a choice box takes Up until its
    top row is highlighted, then A; text takes A, or B once a sign of control
    shows or has shown in the scene; a tutorial card takes A; the controls hint
    with no text box held 1 s ends it; anything else (a cutscene, a banner)
    takes A, or B once control has shown. Presses are held 160 ms, released 240.
    [scene_timeout] after 360 s.

    Not ported (no 01.00b or 01.01 scene uses them): [stop_at_choice],
    [stop_at_battle], [end_at_battle], the lock-on, [start_window_ms], the B
    button and [press_a_first]. The party bar, the A prompt and "mission
    complete" have no reader yet ({!Story_look}). *)

type config = { end_on_black_fade : bool }

val run : Story_steps.game_steps -> string -> config -> Story_steps.outcome
(** [run steps label config]; [label] names it in the log ("scene"). *)
