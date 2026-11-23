(** Reader: what may be an evolution, so nothing presses B on it (any B cancels
    one: pokefirered evolution_scene.c; console B, 2026-11-02, Squirtle stayed
    Lv16 after a battle loop's B presses). The scene loads the battle's text box
    (LoadBattleTextboxAndBackground) but no HP boxes, and "What? ... is
    evolving!" stays up through the animation with no arrow. Ported from the
    fork's EvolutionHold::holds (Programs/AutoStory/
    PokemonFRLG_AutoStoryBattleDecisions): the teal text box with no HP box, no
    arrow, no YES/NO box, and not a dark cave's black (which reads as the text
    box).

    The same screen shows while a trainer's lines print before or after the
    battle, under a wild battle's opening before the HP boxes slide in (3 Switch
    captures) and under a double battle's text, whose HP boxes sit where
    {!Battle_screen.hp_box} does not look (2 mGBA captures); the caller decides
    what to make of it (the fork: an evolution only after a turn that attacked).
    No probes of its own: the caller subscribes {!Battle_screen},
    {!Battle_text_arrow}, {!Battle_yes_no} and {!Dark_corners}'s.

    Unverified: no capture of an evolution yet; checked only that no other
    capture at hand with HP boxes, an arrow, a YES/NO box or a dark cave reads
    as one. *)

val evolution_shows : Effects.measurements -> bool
