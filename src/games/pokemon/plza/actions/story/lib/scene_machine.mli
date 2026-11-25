(** A story scene pressed through to its end: [run_scene_machine] of
    PokemonLZA_AutoStorySceneMachine.cpp ([plza/lean]) with the configs 01.01's
    to 02.01's scenes use, its classes, presses and timings. Each read every 250
    ms is classed:
    - with [stop_at_battle], the battle HUD ends it, and so does a lock-on whose
      ZL brought up the move symbols ({!Lock_on}); after a battle's black fade,
      3 s of a still screen or the party bar with nothing busy (or 1 s of the
      party bar while the A prompt shows instead) hold ZL 2 s (from the second
      try, a quarter turn right and L first), five tries at most;
    - a fade waits (or, with [end_on_black_fade], a black fade ends it);
    - a choice box ends it with [stop_at_choice], else takes Up until its top
      row is highlighted, then A;
    - text takes the scene's button, or B once a sign of control shows or has
      shown in the scene (with [stop_at_choice]: the button B, or A once per
      page);
    - a tutorial card takes A;
    - a sign of control (the party bar, the controls hint or an A prompt, no
      text box) held 1 s ends it; with [stop_at_choice] or [stop_at_battle] only
      the controls hint does, and the party bar or the A prompt held 5 s with
      nothing busy fails it ([scene_ended_in_control]); with a start window and
      no scene seen yet, control waits, and fails [scene_never_started] once the
      window has passed;
    - anything else (a cutscene, a banner) takes the scene's button, or B once
      control has shown, or nothing with [stop_at_choice] or after a battle's
      fade.

    Presses are held 160 ms, released 240. [scene_timeout] after 90 s with
    [stop_at_battle], 120 s with [stop_at_choice], a start window or the button
    B, else 360 s.

    Not ported (no 01.00b to 02.01 scene uses them): [end_at_battle] (a battle
    before a scene's end when a story battle is ahead) and [press_a_first].
    "Mission complete" has no reader yet ({!Story_look}): it reads as a screen
    no detector reads (A, as for the card). *)

type config = {
  end_on_black_fade : bool;
  stop_at_choice : bool;
  stop_at_battle : bool;
      (** the fork's [battle_start]: ends on the battle HUD, with the lock-on *)
  button : Wire.button;  (** A or B: the plan's [button] (A when absent). *)
  start_window_ms : int option;
      (** the fork's [start_window]: control before any scene waits for one this
          long, then fails [scene_never_started] *)
}

val default : config
(** A, no stop at a choice or a battle, no end on a black fade: the plain
    [scene]. *)

val run : Story_steps.game_steps -> string -> config -> Story_steps.outcome
(** [run steps label config]; [label] names it in the log ("scene"). *)
