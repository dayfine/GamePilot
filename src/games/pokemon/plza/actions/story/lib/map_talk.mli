(** Through a talk that opens the map, the plan's [talk_through_map_screen]:
    ported from PokemonLZA_AutoStoryScenes.cpp, 03.02b's Map & Missions card
    after Taunie's battle. A read every 250 ms: A (held 160 ms, released 840) on
    a tutorial card, and on text until the card has shown; B on anything else
    (the map closes with B, where A would place a pin; the talk after it goes on
    with B). Done once the party bar with no text box has held 1 s;
    [map_talk_timeout] after 120 s. *)

val run : Steps.game_steps -> Steps.outcome
