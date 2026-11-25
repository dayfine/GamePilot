(** The flags a PLZA plan's [skip_if] names, read from the screen when the event
    comes up, so a checkpoint resumes from where the console is: 01.03 after a
    lost battle with Andi (Urbain heals the starter and Andi challenges again)
    or inside it. The fork resumes 01.03 by its [resume_at] option instead; we
    differ in reading the screen.

    - ["talk_or_battle_shows"]: a dialogue box, a choice, a tutorial card, a
      fade or the battle HUD shows (not free control in the battle area);
    - ["battle_shows"]: the battle HUD shows.

    Each is read over 1 s (five reads 250 ms apart): any read showing it holds.
    An unknown flag is logged and does not hold. *)

val holds : Plza_story.Story_steps.game_steps -> string -> bool
