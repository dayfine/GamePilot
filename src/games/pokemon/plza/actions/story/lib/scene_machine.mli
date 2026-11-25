(** A story scene pressed through to its end: [run_scene_machine] of
    PokemonLZA_AutoStorySceneMachine.cpp ([plza/lean]) with the configs 01.01's
    and 01.02's scenes use, its classes, presses and timings. Each read every
    250 ms is classed: a fade waits (or, with [end_on_black_fade], a black fade
    ends it); a choice box ends it with [stop_at_choice], else takes Up until
    its top row is highlighted, then A; text takes the scene's button, or B once
    a sign of control shows or has shown in the scene (with [stop_at_choice]:
    the button B, or A once per page); a tutorial card takes A; a sign of
    control (the controls hint or an A prompt, no text box) held 1 s ends it,
    with [stop_at_choice] only the controls hint, while the A prompt held 5 s
    with nothing busy fails it ([scene_ended_in_control]); anything else (a
    cutscene, a banner) takes the scene's button, or B once control has shown,
    or nothing with [stop_at_choice]. Presses are held 160 ms, released 240.
    [scene_timeout] after 120 s with [stop_at_choice] or the button B, else 360
    s.

    Not ported (no 01.00b to 01.02 scene uses them): [stop_at_battle],
    [end_at_battle], the lock-on, [start_window_ms] and [press_a_first]. The
    party bar and "mission complete" have no reader yet ({!Story_look}). *)

type config = {
  end_on_black_fade : bool;
  stop_at_choice : bool;
  button : Wire.button;  (** A or B: the plan's [button] (A when absent). *)
}

val default : config
(** A, no stop at a choice, no end on a black fade: the plain [scene]. *)

val run : Story_steps.game_steps -> string -> config -> Story_steps.outcome
(** [run steps label config]; [label] names it in the log ("scene"). *)
