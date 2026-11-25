(** The story screen read live, in the effect context: the PLZA readers' probes
    over the game picture, and each read turned into what a walk reads
    ({!Plza_walk.Walk_screen.t}), as the screen read of
    PokemonLZA_AutoStoryConsoleBackend.cpp fills its look: the HOME menu first
    ({!Switch_home.Home_screen}), else {!Plza_readers.Story_screen}, and whether
    the frame is the last read's ({!Plza_readers.Frame_cells}). A read waits for
    a frame newer than the inputs sent before it (500 ms at most).

    Where it differs: the walk's read only, for the skeleton's walk; the story
    actions' fuller look comes with them in a later PR. *)

val tile_color : Switch_home.Home_screen.tile_color
(** The HOME menu's selected tile, as the HOME check looks for it. *)

val probes :
  picture:Wire.box -> assets:Plza_readers.Blob_assets.t -> Wire.probe_spec list
(** Every probe a read needs; subscribe them around the run. *)

val game_steps :
  log:(string -> unit) ->
  log_detail:(string -> unit) ->
  Plza_walk.Walk.game_steps
(** The walk's steps on the live game: inputs through {!Effects.submit}, reads
    as above. *)
