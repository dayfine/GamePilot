(** Up 16-up-to-the-rooftop's ladder to the roof, the plan's [climb_ladder]:
    ported from the ladder climb of PokemonLZA_AutoStoryScenes.cpp and the steps
    along a wall until a prompt of PokemonLZA_AutoStoryWalks.cpp. The side
    street's run stops left or right of the ladder, so: the stick ahead 150 ms
    (released 500), then until "Climb Up" shows (only facing the ladder), steps
    along the wall, five to the left, then eleven to the right, back past the
    start, each 250 ms sideways (released 100) and 120 ms ahead (released 500),
    all walking; A through the prompt ({!Talk_prompt.press_through}), then the
    stick ahead 6.5 s up the ladder. [ladder_not_found] when no step showed the
    prompt. *)

type game_steps = Talk_prompt.game_steps
(** What the climb reads and does: a prompt's. *)

val run : game_steps -> (unit, Engine_run.Failure.cause) result
(** Up the ladder, as above. *)
