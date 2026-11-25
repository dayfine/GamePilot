(** A PLZA walk: timed legs of the left stick ({!Plza_rules.Walk_args}), played
    only once the player has free control, and, with an end, the last leg held
    in slices until it shows. A transparent port of the walk in
    [PokemonLZA_AutoStoryWalks.cpp] and [PokemonLZA_AutoStoryActionTable.cpp]:
    the same presses, order and timings.

    The camera follows the player and a walk goes where it looks, so a
    {!Plza_rules.Walk_args.Face_then_walk} leg first faces its angle: an L press
    (the camera recentres behind the player, 100 ms held, 150 ms released), a
    150 ms tilt toward the angle (released 100 ms), and L again; then it holds
    the stick straight on. A {!Plza_rules.Walk_args.Steer} move holds each leg
    at its own angle instead, with an L press before an angled leg after the
    first. A facing or walk after which the screen stayed still was dropped (or
    walked into a wall) and is played once more. Every walk and held slice asks
    to run ({!Inputs.Run}); [walk_only] walks it, as before dash is unlocked
    (01.01).

    With a story battle ahead in the checkpoint ([battle_ahead]), as the fork's
    walk action (PokemonLZA_AutoStoryActionTable.cpp, fork PR 725 on its
    plza/lean branch): the battle HUD before the walk, on two reads in a row of
    its last leg, or after a failed walk is [battle_on_screen] ({!Battle_stop}),
    and the caller goes on at the battle. The map walks ({!Map_walk}) do not
    stop on a battle, as the fork's do not. *)

type game_steps = Leg_play.game_steps = {
  submit : Wire.command -> unit;
      (** Send one input and return once it is done. *)
  read_screen : unit -> Screen.t;  (** Read the screen. *)
  log : string -> unit;  (** A line for the log and the watch page. *)
  log_detail : string -> unit;  (** A line for the log alone. *)
}
(** What a walk reads and does in the game. *)

type outcome = (unit, Engine_run.Failure.cause) result
(** [Ok], or the walk's failure. *)

val play_legs :
  game_steps -> walk_only:bool -> Plza_rules.Walk_args.move -> outcome
(** Plays every leg as timed. Fails only on a tilt that cannot be sent. *)

val walk_to_end :
  game_steps ->
  walk_only:bool ->
  stop_on_battle:bool ->
  string ->
  Plza_rules.Walk_args.move ->
  until:Plza_rules.Walk_args.until ->
  earliest_end_ms:int ->
  outcome
(** [walk_to_end steps ~walk_only ~stop_on_battle walk move ~until
     ~earliest_end_ms]: plays all but the last leg's walk, then holds the last
    leg in slices of up to 250 ms, reading the screen after each, until [until]
    shows (an end event seen before [earliest_end_ms] of the leg was passed on
    the way) or a black fade ends it (a scene takes over). The leg's time is the
    budget: [walk_no_end] after it with no end event, [walk_no_scene] when
    control stayed free. With {!Plza_rules.Walk_args.Scene}, two busy reads in a
    row (text, a box or a fade) end it. With [stop_on_battle] (a story battle
    ahead), the battle HUD on two reads in a row, in the slices or in a talk's
    reads after them, stops the walk there: [battle_on_screen], logged with the
    time held. *)

val run_event :
  game_steps ->
  walk_only:bool ->
  battle_ahead:bool ->
  string ->
  Plza_rules.Walk_args.t ->
  outcome
(** A walk event: with [battle_ahead], [battle_on_screen] at once when the
    battle HUD shows ({!Battle_stop.showing}); then the wait before, then
    {!Free_control_wait.wait}, then {!walk_to_end} with an end, or {!play_legs}
    without one, then the final screen logged. A walk with a heading faces it
    first, once control is free ({!Face_heading}), as the fork's walk step does
    (PokemonLZA_AutoStoryActionTable.cpp). With [battle_ahead], the last leg
    stops on the battle HUD, and a failed walk with the HUD showing after it is
    [battle_on_screen]. *)
