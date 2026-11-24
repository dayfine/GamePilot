(** Runs one checkpoint of a FireRed plan live: the start state loaded (when
    given), the overworld's probes subscribed, then the plan's events through
    {!Story.Runner} with FireRed's {!Frlg_actions.Story_game}. What
    [gamepilot checkpoint] runs, and replays from its wire log. *)

type options = {
  state : string option;
      (** A save state of the checkpoint's start, loaded first and again on
          reload. *)
  party : Frlg_actions.Party_roster.t option;
      (** The party at the start; [None]: read from the game when an action
          first needs it ({!Frlg_actions.Story_game.config}). *)
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
          live check that a state holds what a checkpoint promises. *)
  log : string -> unit;
}

val maps_dir : string
(** PokemonSimulation's FireRed maps, from the repo root. *)

val load_world : unit -> (Frlg_overworld.Frlg_steps.world, string) result
(** Every runtime map of {!maps_dir}, found from the working directory, as mGBA
    walks them: map edges do not stall ({!Frlg_overworld.Frlg_steps.world}). *)

val check_plan : Story.Plan.t -> (unit, string) result
(** A FireRed plan whose [execution.menu], when given, is ["full"]: the Start
    menu rows the actions press to (POKéMON 1, BAG 2, SAVE 4). *)

val start_of : Story.Plan.checkpoint -> Story.Pose.observed option
(** The checkpoint's [start] when it names one tile. *)

val capped_postconditions :
  grind_cap:int option ->
  Story.Plan.t ->
  Story.Plan.postconditions * string list
(** The postconditions a run checks, and the ones it skips, one line each
    (["knows mr-mime recycle (grind capped at 8)"],
    ["level mr-mime at least 33 (grind capped at 8)"]): with a grind cap, the
    [knows] and [levels] ones, a grind's goal a capped grind does not reach;
    none without. *)

val run :
  ?end_at:Story.Pose.grid ->
  ?on_event:(int -> Story.Event_progress.t -> unit) ->
  options ->
  Frlg_overworld.Frlg_steps.world ->
  Story.Plan.t ->
  (unit, Story.Failure.t) result
(** In the effect context: loads the state and runs the checkpoint with the
    overworld's probes ({!Frlg_readers.Screen_facts.probes}) subscribed; a walk,
    a settle, a menu action and a battle add their own while they run. With
    [end_at], the player must end there ({!Story.Runner.run}); FireRed reads no
    position yet, so it is where the walks tracked the player. Then the plan's
    postconditions ({!Story.Plan.postconditions}), read by
    {!Postcondition_reads}, must all pass, but for those
    {!capped_postconditions} skips (logged). [on_event] hears each event's
    progress ({!Story.Runner.run}). *)
