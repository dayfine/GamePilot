(** 00.00-new-game's new game ({!Plza_story.New_game_intro}) on the live
    console: its screen read in the effect context, the HOME menu
    ({!Switch.Home_screen}), the intro's screens
    ({!Plza_readers.Intro_screens}), the name keyboard's cursor and text field
    ({!Switch.Keyboard_typing}) and Confirm Choices
    ({!Plza_readers.Confirm_choices}), each read on a frame newer than the
    inputs sent before it ({!Live_story_screen.fresh}).

    The launch is the fork's (PokemonLZA_AutoStoryLaunch.cpp): it closes the
    running game, walks HOME's row to PLZA's tile by its title
    ({!Switch.Home_title.find_tile}, {!Plza_readers.Switch_home_tile}: HOME 160
    ms, 960 ms after; Right 80 ms, 500 ms after; up to 8 tiles), and starts the
    game on that tile with the first user ({!Switch.Game_entry}). Where it
    differs: the title is matched to a template, not read by OCR, and the fork's
    log line naming the running game's tile before the close is not written. *)

val probes :
  picture:Wire.box -> home_title:Effects.template_hash -> Wire.probe_spec list
(** The probes a read needs, subscribed only while 00.00-new-game runs, with
    PLZA's HOME title template ({!Plza_readers.Switch_home_tile.title_template})
    uploaded. *)

val run :
  picture:Wire.box ->
  log:(string -> unit) ->
  home_title:Effects.template_hash ->
  Plza_story.New_game_choices.t ->
  Plza_story.Steps.outcome
(** The new game, with {!probes} subscribed around it. *)
