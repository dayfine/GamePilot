(** The story screen read live, in the effect context: the PLZA readers' probes
    over the game picture, and each read turned into a {!Plza_story.Look.t}, as
    the screen read of PokemonLZA_AutoStoryConsoleBackend.cpp fills its look:
    the HOME menu first ({!Switch_home.Home_screen}), else
    {!Plza_readers.Story_screen}, the Confirm Choices row
    ({!Plza_readers.Confirm_choices}), and whether the frame is the last read's
    ({!Plza_readers.Frame_cells}). The probes also serve the reload
    ({!Game_reload}): the loading screens ({!Plza_readers.Game_loading}) and the
    backup save's arrow ({!Plza_readers.Choice_arrow}). A read waits for a frame
    newer than the inputs sent before it (500 ms at most). *)

val probes :
  picture:Wire.box -> assets:Plza_readers.Blob_assets.t -> Wire.probe_spec list
(** Every probe a read needs; subscribe them around the run. *)

val game_steps :
  picture:Wire.box ->
  log:(string -> unit) ->
  log_detail:(string -> unit) ->
  Plza_story.Steps.game_steps
(** The story actions' steps on the live game: inputs through {!Effects.submit},
    reads as above. *)
