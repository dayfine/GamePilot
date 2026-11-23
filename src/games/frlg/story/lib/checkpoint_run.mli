(** Runs one checkpoint of a FireRed plan live: the start state loaded (when
    given), the readers' probes subscribed, then the plan's events through
    {!Story.Runner} with FireRed's {!Frlg_actions.Story_game}. What
    [gamepilot checkpoint] runs, and replays from its wire log. *)

type options = {
  state : string option;
      (** A save state of the checkpoint's start, loaded first and again on
          reload. *)
  party : Frlg_actions.Party_roster.t;  (** The party at the start. *)
  center : string option;  (** The town whose Center heals between rounds. *)
  gait : Frlg_overworld.Route_legs.gait;
  log : string -> unit;
}

val maps_dir : string
(** PokemonSimulation's FireRed maps, from the repo root. *)

val load_world : unit -> (Frlg_overworld.Frlg_steps.world, string) result
(** Every runtime map of {!maps_dir}, found from the working directory. *)

val check_plan : Story.Plan.t -> (unit, string) result
(** A FireRed plan whose [execution.menu], when given, is ["full"]: the Start
    menu rows the actions press to (POKéMON 1, BAG 2, SAVE 4). *)

val start_of : Story.Plan.checkpoint -> Story.Pose.observed option
(** The checkpoint's [start] when it names one tile. *)

val probes : Wire.probe_spec list
(** Every reader the story game uses, each probe once. *)

val run :
  options ->
  Frlg_overworld.Frlg_steps.world ->
  Story.Plan.t ->
  (unit, Story.Failure.t) result
(** In the effect context: loads the state, subscribes {!probes}, runs the
    checkpoint. *)
