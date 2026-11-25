(** Up 03.03b's ladder to the roof: [climb_ladder] and [step_along_until_prompt]
    of PokemonLZA_AutoStoryScenes.cpp and PokemonLZA_AutoStoryWalks.cpp
    ([plza/lean]). The side street's run stops left or right of the ladder, so:
    the stick ahead 150 ms (released 500), then until "Climb Up" shows (only
    facing the ladder), steps along the wall, five to the left, then eleven to
    the right, back past the start, each 250 ms sideways (released 100) and 120
    ms ahead (released 500), all walking; A through the prompt
    ({!Talk_prompt.press_through}), then the stick ahead 6.5 s up the ladder.
    [ladder_not_found] when no step showed the prompt. *)

type game_steps = Talk_prompt.game_steps

val run : game_steps -> (unit, Engine_run.Failure.cause) result
