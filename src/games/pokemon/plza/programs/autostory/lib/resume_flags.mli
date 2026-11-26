(** The flags a PLZA plan's [skip_if] names, read from the screen when the event
    comes up, so a checkpoint resumes from where the console is: 01.04 after a
    lost battle with Andi (Urbain heals the starter and Andi challenges again),
    inside it, or after it in free control. The fork resumes 01.03 by an option
    naming the action to resume at instead; we differ in reading the screen.

    - ["talk_or_battle_shows"]: a dialogue box, a choice, a tutorial card, a
      fade or the battle HUD shows (not free control in the battle area);
    - ["battle_shows"]: the battle HUD shows;
    - ["party_bar_free"]: the party bar with no text box, fade, chevron or
      battle HUD (the fork's free party bar,
      PokemonLZA_AutoStoryScreenPredicates.h, less the battle): free control
      with a Pokémon in the party, so after 01.04's starter;
    - ["minimap:<name>"]: the minimap reads as the recorded one
      ({!Plza_readers.Minimap}, ["minimap:after-taunie-battle"]): where a
      checkpoint ends when the next one's start signature names it. 03.03's end,
      the plaza arch, shows the party bar as its start does, but its minimap
      only after the map talk.

    The screen is woken first ({!Plza_story.Screen_wake}): a dimmed one reads as
    nothing. Each is read over 1 s (five reads 250 ms apart): the first two hold
    when any read shows them, ["party_bar_free"] and the minimap only when every
    read does (a battle HUD missed once must not skip the battle). An unknown
    flag is logged and does not hold. *)

val known : string -> (unit, string) result
(** The flag is one of the above, its minimap a recorded one; else why not.
    Checked when the plan loads. *)

val holds : Plza_story.Steps.game_steps -> string -> bool
(** The flag holds on the screen now, read as above. *)
