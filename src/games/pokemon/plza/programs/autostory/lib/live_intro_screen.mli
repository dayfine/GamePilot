(** 01.00a's new game ({!Plza_story.New_game_intro}) on the live console: its
    screen read in the effect context, the HOME menu
    ({!Switch_home.Home_screen}), the intro's screens
    ({!Plza_readers.Intro_screens}), the name keyboard's cursor and text field
    ({!Switch_home.Keyboard_typing}) and Confirm Choices
    ({!Plza_readers.Confirm_choices}), each read on a frame newer than the
    inputs sent before it ({!Live_story_screen.fresh}).

    The launch closes the running game and starts PLZA from HOME's first tile
    with the first user ({!Switch_home.Game_entry}), as {!Game_reload} does. The
    fork finds PLZA's tile among HOME's first 8 by its title (OCR,
    PokemonLZA_AutoStoryLaunch.cpp); here PLZA must be the game played last. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The probes a read needs, subscribed only while 01.00a runs. *)

val run :
  picture:Wire.box ->
  log:(string -> unit) ->
  Plza_story.New_game_choices.t ->
  Plza_story.Steps.outcome
(** The new game, with {!probes} subscribed around it. *)
