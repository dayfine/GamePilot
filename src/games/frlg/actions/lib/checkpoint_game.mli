(** FireRed's story {!Pokemon_checkpoints.Game.t}: [route] and [ready] events
    planned and walked ({!Frlg_overworld}), [talk], [answer] and [scene] settled
    ({!Talk}), [heal] and [save] events ({!Heal_and_save}), the ["fly"] game
    action ({!Fly}), ["lift_floor"] ({!Lift_ride}), the ["grind"] one ({!Grind},
    its walks and heals this game's), ["capture"] ({!Capture} on
    {!Capture_steps}; its catches join the reckoned party), mg-05's
    ["prepare_berry_pp"] ({!Berry_pp}) and ["mail_glitch_double_battle"]
    ({!Mail_glitch_battle}) and the shared ones ({!Game_actions}). Battles and
    the other built-in kinds fail as [not_implemented] (repeats): they come from
    their own libraries.

    Between loop rounds, heal walks to the configured Center's nurse and talks
    to her, save saves from the Start menu, and reload is the program's (an
    emulator loads a state; a console would soft reset).

    FireRed can't show where the player stands, so the position is reckoned: a
    walk ends on its plan's tile, a Fly on the town's landing tile, a lift ride
    below the floor's lift door, and after any other event that passes, game
    actions included, the player is taken to be where its [declared_after] says
    when that names one tile (the fork's StoryStepRunner). The party is reckoned
    too ({!Party_roster}), from the config's or, when the config states none,
    from the members' summaries read before the first action that finds a member
    by its species ({!Party_reading}). *)

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
  center : string option;
      (** The town whose Pokémon Center heals between loop rounds
          (["LavenderTown"]); [None]: heal fails as [not_implemented]. *)
  reload : unit -> (unit, Pokemon_checkpoints.Failure.cause) result;
      (** Back to the checkpoint's start state. *)
  log : string -> unit;
}

type t

val create : config -> start:Pokemon_checkpoints.Pose.observed option -> t
(** [start]: where the player stands at the checkpoint's start, if known. *)

val game : t -> Pokemon_checkpoints.Game.t

val party : t -> Party_roster.t
(** The party as reckoned now. *)
