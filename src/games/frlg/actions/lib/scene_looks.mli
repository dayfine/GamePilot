(** The core settle loop ({!Screen_state.Settle}) fed by FireRed's readers: a
    look is {!Frlg_readers.Screen_facts} on the latest frame, plus the two facts
    one frame can't give, worked out here.

    - Free control: no fade, no box, no battle and no Start menu.
    - Screen still: the middle of the screen (the fade probe's mean) moved less
      than {!max_still_change} since the last look.

    The fork has no FireRed reader for either (its FrlgScreenObserver leaves
    them out); both thresholds want a recorded mGBA settle to check them. Text
    is pressed through with B, as the fork's AutoStory does: B never starts a
    talk and never answers yes. *)

val probes : Wire.probe_spec list
(** What the looks read: {!Frlg_readers.Screen_facts.probes} and the Start
    menu's. *)

val max_still_change : float
(** The sum of the three channels' mean change over the middle of the screen
    below which it counts as still: 3. *)

val io :
  ?menu_open:(Effects.measurements -> bool) ->
  ?arrived:(Effects.measurements -> bool) ->
  flee_battle:(unit -> bool) ->
  log:(string -> unit) ->
  unit ->
  Screen_state.Settle.io
(** A fresh settle's looks and presses. Each [io] keeps its own last look. A
    look on which [menu_open] holds (default never) is no free control: a menu
    with no box and no fade (the party, a summary) is not the overworld. A look
    of the overworld (no fade, box or battle) on which [arrived] holds (default
    never) is the arrival read. Each press watches every frame of its wait and
    returns the first that showed a warp. *)

val settle :
  ?menu_open:(Effects.measurements -> bool) ->
  ?arrived:(Effects.measurements -> bool) ->
  ?start:Wire.command list ->
  Screen_state.Settle.kind ->
  label:string ->
  battle_ends:bool ->
  log:(string -> unit) ->
  (unit, Checkpoints.Failure.cause) result
(** Runs the settle of that kind with {!probes} subscribed, fleeing no battle.
    [start] (default none): the presses that start the step (the item's USE),
    run once the probes are subscribed with every frame watched, so a warp that
    begins during them counts. [arrived]: as for {!io}; its readers' probes are
    the caller's to subscribe. The settle ends [Ok] once quiet, or when a battle
    starts if [battle_ends] (a trainer's after their talk, which the plan's next
    event fights); else a battle fails as [battle]. The cap fails as
    [not_settled]. *)
