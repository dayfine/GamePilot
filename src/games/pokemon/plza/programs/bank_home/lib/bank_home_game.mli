(** [plza.bank-home]'s checkpoints as a game of the checkpoint engine
    ({!Plza_engine}): one game action, [bank_in_home], which opens Pokémon HOME
    on Legends: Z-A from the Switch's HOME menu, moves the gifts its args name
    ({!Bank_moves_args}, the run's options over them) from the game's box to
    their HOME boxes, saves HOME and closes it ({!Pokemon_home.Home_bank}).
    Pokémon HOME's save banner, then its main menu or saved banner, is the
    checkpoint's end check, inside the action.

    Its start check ({!start_check}) finds Legends: Z-A's tile on the Switch's
    HOME menu. Not in the fork, which banks nothing in Pokémon HOME. *)

type templates = {
  home : Pokemon_home.Home_bank.templates;
      (** What Pokémon HOME's steps find their way by. *)
  plza_title : string;
      (** PNG: "Legends: Z-A" over HOME's tile row, the cursor on its tile
          ({!Switch_home.Home_title}). *)
}
(** The PNG templates a run uploads. *)

val action : string
(** ["bank_in_home"]: the one game action a plan names. *)

val check_plan : Run_options.t -> Plza_engine.Plan.t -> (unit, string) result
(** Before the console moves: every event is a {!action} whose moves read with
    the run's options ({!Bank_moves_args.moves}), and there is one at least. *)

val start_check :
  log:(string -> unit) -> templates -> (unit, Engine_run.Failure.cause) result
(** From anywhere the HOME button reaches the Switch's HOME menu: HOME (100 ms,
    released 1 s) to the first tile, then Right (80 ms, released 600) along the
    row, each tile's title read for 1.5 s, up to 8 tiles
    ({!Switch_home.Home_title.find_tile}); the cursor is left on Legends: Z-A's
    tile, or [home_tile_not_found] (repeats). *)

val make :
  log:(string -> unit) ->
  picture:Wire.box ->
  options:Run_options.t ->
  templates ->
  Plza_engine.Game.t
(** The handlers of one run: {!action} only. A walk, a scene, a talk, a save or
    a reload fails [no_handler]: Pokémon HOME saves inside the action, and a
    failed bank leaves HOME open for a look. *)
