(** Runs one checkpoint of a FireRed plan live: the start state loaded (when
    given), the overworld's probes subscribed, then the plan's events through
    {!Pokemon_engine.Runner} with FireRed's {!Frlg_actions.Checkpoint_game}.
    What [gamepilot run --plan] runs, and replays from its wire log. *)

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
  program_options : Run_options.t;
      (** The program's options (gamepilot run --options), for its game actions
          ({!Frlg_actions.Checkpoint_game.config}). *)
  default_frame_model : string;
      (** Default RNG frame model (["mgba"] or ["switch"]) when a plan omits
          ["frame_model"]. *)
  log : string -> unit;
}

val maps_dir : string
(** PokemonSimulation's FireRed maps, from the repo root. *)

val load_world : unit -> (Frlg_overworld.Frlg_steps.world, string) result
(** Every runtime map of {!maps_dir}, found from the working directory, but the
    standard Pokemon Centers' (the shared layout's), and the coded room of each
    of those Centers in their place
    ({!Frlg_overworld.Standard_center.with_rooms}): the coded room wins, and a
    standard Center's map file is not read. As mGBA walks them: map edges do not
    stall ({!Frlg_overworld.Frlg_steps.world}). *)

val load_map : string -> (Grid_maps.Map_data.t, string) result
(** The map of that name as {!load_world} has it: a standard Center's coded
    room, or else its runtime file. *)

val check_plan : Pokemon_engine.Plan.t -> (unit, string) result
(** A FireRed plan whose [execution.menu], when given, is ["full"]: the Start
    menu rows the actions press to (POKéMON 1, BAG 2, SAVE 4); and whose first
    event, when it starts anywhere outdoors, is a [fly]: FireRed does not read
    the map, so only a Fly's landing tells it where the player is. *)

val start_of :
  Pokemon_engine.Plan.checkpoint -> Pokemon_engine.Pose.observed option
(** The checkpoint's [start] when it names one tile. *)

val capped_postconditions :
  grind_cap:int option ->
  Pokemon_engine.Plan.t ->
  Pokemon_engine.Postconditions.t * string list
(** The postconditions a run checks, and the ones it skips, one line each
    (["knows mr-mime recycle (grind capped at 8)"],
    ["level mr-mime at least 33 (grind capped at 8)"]): with a grind cap, the
    [knows] and [levels] ones, a grind's goal a capped grind does not reach;
    none without. *)

type from_event = {
  range : Engine_run.Event_range.t;
  kept : Pokemon_engine.Saved.t;
      (** What the run that kept the first event's state read at the
          checkpoint's start ({!Pokemon_engine.Event_snapshot}). *)
}
(** A partial run: its events, from a state kept at the first one's start. *)

type keep_event_state =
  index:int -> Pokemon_engine.Plan.event -> Pokemon_engine.Saved.t -> unit
(** Keeps the state at an event's start, with the checkpoint's start reads. *)

val run :
  ?end_at:Pokemon_engine.Pose.grid ->
  ?on_event:(int -> string Engine_run.Event_progress.t -> unit) ->
  ?actions:(string * Pokemon_engine.Game.game_action) list ->
  ?from_event:from_event ->
  ?keep_event_state:keep_event_state ->
  options ->
  Frlg_overworld.Frlg_steps.world ->
  Pokemon_engine.Plan.t ->
  (unit, Pokemon_engine.Failure.t) result
(** In the effect context: loads the state and runs the checkpoint with the
    overworld's probes ({!Frlg_readers.Screen_facts.probes}) subscribed; a walk,
    a settle, a menu action and a battle add their own while they run. With
    [end_at], the player must end there ({!Pokemon_engine.Runner.run}); FireRed
    reads no position yet, so it is where the walks tracked the player. Then the
    plan's postconditions ({!Pokemon_engine.Postconditions.t}), read by
    {!Postcondition_reads}, must all pass (a promise of a change against the
    count read before the first event, {!Postcondition_reads.at_start}), but for
    those {!capped_postconditions} skips (logged). [on_event] hears each event's
    progress ({!Pokemon_engine.Runner.run}). [actions] are game actions of the
    caller's own, ahead of FireRed's: a shadow plan's ({!Shadow_plan}).

    With [from_event], only its events run ({!Pokemon_engine.Runner.run}), from
    [options.state], the state kept at the first one's start; a promise of a
    change is checked against the start reads kept with that state, never
    re-read at the event (logged), and the walks start where the run that kept
    it reckoned the player to stand. [keep_event_state] is called at the start
    of each event the run reached cleanly
    ({!Pokemon_engine.Event_snapshot.hear}), with what the run read at the
    checkpoint's start (or, on a partial run, what was kept). *)

val goal_holds :
  log:(string -> unit) -> id:string -> Pokemon_engine.Postconditions.t -> bool
(** In the effect context, from the overworld and back to it: whether a
    repeating checkpoint's goal ({!Pokemon_engine.Plan.repeat}'s [until]) holds
    now, read as postconditions are ({!Postcondition_reads}) and logged
    (["[Goal] [Postcondition] 05-grind-mr-mime ..."]). A goal with nothing in
    it, or one not read, does not hold. *)
