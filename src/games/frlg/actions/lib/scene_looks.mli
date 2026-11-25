(** The core settle loop ({!Screen_state.Settle}) fed by FireRed's readers: a
    look is {!Frlg_readers.Screen_facts} on the latest frame, plus the two facts
    one frame can't give, worked out here.

    - Free control: no fade, no box, no battle and no Start menu.
    - Screen still: the middle of the screen (the fade probe's mean) moved less
      than {!max_still_change} since the last look.

    The fork has no FireRed reader for either (its FrlgScreenObserver leaves
    them out); both thresholds want a recorded mGBA settle to check them. Text
    is pressed through with B, as the fork's AutoStory does: B never starts a
    talk and never answers yes.

    A settle that awaits fade-ins ([await_fade_in]) also feeds every frame it
    sees to a {!Frlg_overworld.Warp_fade_in.watch}: from a fade until its
    fade-in is over, a look is no free control and a press sends no B, only the
    wait. FireRed's fade-in first holds a dim, still screen for about 33 frames,
    which reads as no fade: a B there is lost or, if the spell lasts the quiet,
    the settle ends before the game takes input. The fork presses B through it
    (advance_text in Programs/AutoStory/PokemonFRLG_AutoStoryActions.cpp mashes
    B, then proves the overworld by opening the Start menu); we deliberately
    differ and send nothing until the fade-in is over. *)

val probes : Wire.probe_spec list
(** What the looks read: {!Frlg_readers.Screen_facts.probes} and the Start
    menu's. *)

val max_still_change : float
(** The sum of the three channels' mean change over the middle of the screen
    below which it counts as still: 3. *)

val io :
  ?menu_open:(Effects.measurements -> bool) ->
  ?arrived:(Effects.measurements -> bool) ->
  ?await_fade_in:bool ->
  flee_battle:(unit -> bool) ->
  log:(string -> unit) ->
  unit ->
  Screen_state.Settle.io
(** A fresh settle's looks and presses. Each [io] keeps its own last look. A
    look on which [menu_open] holds (default never) is no free control: a menu
    with no box and no fade (the party, a summary) is not the overworld. A look
    of the overworld (no fade, box or battle) on which [arrived] holds (default
    never) is the arrival read. With [await_fade_in] (default false), a look
    while a fade-in is still coming up is no free control and its press sends no
    B. Each press watches every frame of its wait and returns the first that
    showed a warp. *)

val settle :
  ?menu_open:(Effects.measurements -> bool) ->
  ?arrived:(Effects.measurements -> bool) ->
  ?await_fade_in:bool ->
  ?start:Wire.command list ->
  Screen_state.Settle.kind ->
  label:string ->
  battle_ends:bool ->
  log:(string -> unit) ->
  (unit, Pokemon_checkpoints.Failure.cause) result
(** Runs the settle of that kind with {!probes} subscribed, fleeing no battle.
    [start] (default none): the presses that start the step (the item's USE),
    run once the probes are subscribed with every frame watched, so a warp that
    begins during them counts. [arrived]: as for {!io}; its readers' probes are
    the caller's to subscribe. [await_fade_in]: as for {!io}. The settle ends
    [Ok] once quiet, or when a battle starts if [battle_ends] (a trainer's after
    their talk, which the plan's next event fights); else a battle fails as
    [battle]. The cap fails as [not_settled]. *)

val until_battle :
  label:string ->
  log:(string -> unit) ->
  (unit, Pokemon_checkpoints.Failure.cause) result
(** The talk settle through a scene's text until a battle starts: a trainer's
    next battle, after the lines between two of them. Fails as [no_battle] when
    the overworld goes quiet first, and as [not_settled] at the cap. *)
