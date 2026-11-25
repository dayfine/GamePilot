(** Runs one checkpoint of a FireRed plan live: the start state loaded (when
    given), the overworld's probes subscribed, then the plan's events through
    {!Checkpoints_run.Runner} with FireRed's {!Frlg_actions.Checkpoint_game}.
    What [gamepilot checkpoint] runs, and replays from its wire log. *)

type options = {
  state : string option;
      (** A save state of the checkpoint's start, loaded first and again on
          reload. *)
  party : Frlg_actions.Party_roster.t option;
      (** The party at the start; [None]: read from the game when an action
          first needs it ({!Frlg_actions.Checkpoint_game.config}). *)
  center : string option;  (** The town whose Center heals between rounds. *)
  grind_cap : int option;
      (** Testing: each grind ends, passing, after this many battles, and the
          [knows] and [levels] postconditions (the grind's goal) are skipped,
          logged as such. A capped run's end is not the next checkpoint's start.
      *)
  gait : Frlg_overworld.Route_legs.gait;
  end_check_only : bool;
      (** Run no events: the start state's postconditions checked alone (the end
          position too is not checked: FireRed reckons it from the walks). A
          live check that a state holds what a checkpoint promises; a promise of
          a change (the money spent, coins or items gained) is not checked (no
          start read). *)
  log : string -> unit;
}

val maps_dir : string
(** PokemonSimulation's FireRed maps, from the repo root. *)

val load_world : unit -> (Frlg_overworld.Frlg_steps.world, string) result
(** Every runtime map of {!maps_dir}, found from the working directory, as mGBA
    walks them: map edges do not stall ({!Frlg_overworld.Frlg_steps.world}). *)

val check_plan : Checkpoints_plan.Plan.t -> (unit, string) result
(** A FireRed plan whose [execution.menu], when given, is ["full"]: the Start
    menu rows the actions press to (POKéMON 1, BAG 2, SAVE 4). *)

val start_of :
  Checkpoints_plan.Plan.checkpoint -> Checkpoints_plan.Pose.observed option
(** The checkpoint's [start] when it names one tile. *)

val capped_postconditions :
  grind_cap:int option ->
  Checkpoints_plan.Plan.t ->
  Checkpoints_plan.Plan.postconditions * string list
(** The postconditions a run checks, and the ones it skips, one line each
    (["knows mr-mime recycle (grind capped at 8)"],
    ["level mr-mime at least 33 (grind capped at 8)"]): with a grind cap, the
    [knows] and [levels] ones, a grind's goal a capped grind does not reach;
    none without. *)

type from_event = {
  range : Checkpoints_run.Event_range.t;
  kept : Checkpoints_run.Event_states.kept;
      (** What the run that kept the first event's state read at the
          checkpoint's start ({!Checkpoints_run.Event_states}). *)
}
(** A partial run: its events, from a state kept at the first one's start. *)

type keep_event_state =
  index:int ->
  Checkpoints_plan.Plan.event ->
  Checkpoints_run.Event_states.kept ->
  unit
(** Keeps the state at an event's start, with the checkpoint's start reads. *)

val run :
  ?end_at:Checkpoints_plan.Pose.grid ->
  ?on_event:(int -> Checkpoints_run.Event_progress.t -> unit) ->
  ?actions:(string * Checkpoints_run.Game.game_action) list ->
  ?from_event:from_event ->
  ?keep_event_state:keep_event_state ->
  options ->
  Frlg_overworld.Frlg_steps.world ->
  Checkpoints_plan.Plan.t ->
  (unit, Checkpoints_run.Failure.t) result
(** In the effect context: loads the state and runs the checkpoint with the
    overworld's probes ({!Frlg_readers.Screen_facts.probes}) subscribed; a walk,
    a settle, a menu action and a battle add their own while they run. With
    [end_at], the player must end there ({!Checkpoints_run.Runner.run}); FireRed
    reads no position yet, so it is where the walks tracked the player. Then the
    plan's postconditions ({!Checkpoints_plan.Plan.postconditions}), read by
    {!Postcondition_reads}, must all pass (a promise of a change against the
    count read before the first event, {!Postcondition_reads.at_start}), but for
    those {!capped_postconditions} skips (logged). [on_event] hears each event's
    progress ({!Checkpoints_run.Runner.run}). [actions] are game actions of the
    caller's own, ahead of FireRed's: a shadow plan's ({!Shadow_plan}).

    With [from_event], only its events run ({!Checkpoints_run.Runner.run}), from
    [options.state], the state kept at the first one's start; a promise of a
    change is checked against the start reads kept with that state, never
    re-read at the event (logged), and the walks start where the run that kept
    it reckoned the player to stand. [keep_event_state] is called at the start
    of each event the run reached cleanly
    ({!Checkpoints_run.Event_states.hear}), with what the run read at the
    checkpoint's start (or, on a partial run, what was kept). *)

val goal_holds :
  log:(string -> unit) ->
  id:string ->
  Checkpoints_plan.Plan.postconditions ->
  bool
(** In the effect context, from the overworld and back to it: whether a
    repeating checkpoint's goal ({!Checkpoints_plan.Plan.repeat}'s [until])
    holds now, read as postconditions are ({!Postcondition_reads}) and logged
    (["[Goal] [Postcondition] mg-04b ..."]). A goal with nothing in it, or one
    not read, does not hold. *)
