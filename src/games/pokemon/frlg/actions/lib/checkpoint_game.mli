(** FireRed's story {!Pokemon_engine.Game.t}: [route] and [ready] events planned
    and walked ({!Frlg_overworld}), a [step] onto a scene's tile
    ({!Frlg_overworld.Route_walk.step}), [talk], [answer] and [scene] settled
    ({!Talk}), [train]'s trainer battles in a row ({!Trainer_battles}), a
    [battle] a talk or scene started ({!Scene_battle}), [heal] and [save] events
    ({!Heal_and_save}), the ["fly"] game action ({!Fly}), ["lift_floor"]
    ({!Lift_ride}), ["ferry"] ({!Seagallop}), the ["grind"] one ({!Grind}, its
    walks and heals this game's), ["capture"] ({!Capture} on {!Capture_steps};
    its catches join the reckoned party), ["wild_rng"] ({!Wild_rng}),
    ["save_game"] (save from the Start menu, what a hard reset boots from),
    mg-05's ["prepare_berry_pp"] ({!Berry_pp}) and ["mail_glitch_double_battle"]
    ({!Mail_glitch_battle}) and the shared ones ({!Game_actions}). The other
    built-in kinds fail as [not_implemented] (repeats): they come from their own
    libraries. A trainer who sees the player on a walk is fought with
    {!Trainer_battles} too ({!Frlg_overworld.Route_walk}).

    Between loop rounds, heal walks to the configured Center's nurse and talks
    to her, save saves from the Start menu, and reload is the program's (an
    emulator loads a state; a console would soft reset).

    FireRed can't show where the player stands, so the position is reckoned: a
    walk ends on its plan's tile, a Fly on the town's landing tile, a lift ride
    below the floor's lift door, the Seagallop above the island harbor's sailor,
    a step on the tile it presses onto, and after any other event that passes,
    game actions included, the player is taken to be where its [declared_after]
    says when that names one tile (the fork's StoryStepRunner). The party is
    reckoned too ({!Party_roster}), from the config's or, when the config states
    none, from the members' summaries read before the first action that finds a
    member by its species ({!Party_reading}). *)

type config = {
  world : Frlg_overworld.Frlg_steps.world;
  gait : Frlg_overworld.Route_legs.gait;
  flee : unit -> unit;  (** Runs from a wild battle, back to the overworld. *)
  flags : string -> bool;
  party : Party_roster.t option;
      (** The party at the checkpoint's start; [None]: read from the game before
          the first action that finds a member by its species
          ({!Action_args.picks_member}). *)
  grind_cap : int option;
      (** Testing: every ["grind"] ends, passing, after this many battles
          ({!Grind.run}'s [cap]). *)
  center : Pokemon_engine.Pose.grid option;
      (** The nurse's stand pose to heal at between loop rounds (from the places
          table); [None]: heal fails as [not_implemented]. *)
  reload : unit -> (unit, Pokemon_engine.Failure.cause) result;
      (** Back to the checkpoint's start state. *)
  program_options : Run_options.t;
      (** The program's options the run was given (gamepilot run --options,
          checked against its registry entry): a game action of the program's
          reads its choices with {!Run_options.find} or {!Run_options.int}. *)
  default_frame_model : string;
      (** Default RNG frame model (["mgba"] or ["switch"]) used by ["wild_rng"],
          ["gift_rng"], and ["static_rng"] when a plan omits ["frame_model"]. *)
  log : string -> unit;
}

type t

val create : config -> start:Pokemon_engine.Pose.observed option -> t
(** [start]: where the player stands at the checkpoint's start, if known. *)

val game : t -> Pokemon_engine.Game.t

val party : t -> Party_roster.t
(** The party as reckoned now. *)
