(** Walks planned legs on FireRed: a turn tap where the player faces another
    way, each leg's hold through the shared walker ({!Grid_walker.Leg_walker})
    with FireRed's interrupts, a warp's fade and fade-in ({!Warp_fade_in})
    waited out, and the late interrupts a leg's last step sets off cleared.
    Ported from the fork's [walk_overworld_route()]
    (Overworld/PokemonFRLG_OverworldWalk). Uses only the core effects.

    FireRed can't show where the player stands, so the walk is dead reckoned:
    each leg ends on its planned tile. A leg interrupted at once, hold after
    hold, is held into something that speaks: when a sign on the maps explains
    it ({!Before_signs}), the walk goes on from before the sign, else it fails
    rather than guess.

    With [watch_trainers], a leg that crosses the sight of a trainer not beaten
    yet is walked by {!Trainer_crossing}: in pieces, each ending on a tile a
    trainer may see, with a watch for the trainer after each. A trainer who
    speaks is fought with [fight_trainer], and the rest of the walk is planned
    again from that tile, round where the trainer may stand, with the trainer
    beaten for the rest of the walk. Their tiles stay walled for this walk only:
    the next walk plans from [world] again, where they are free. A battle after
    a message elsewhere on a leg (a trainer the maps do not put there) still
    fails the walk. *)

open Grid_maps
open Grid_geometry

type t = {
  world : Frlg_steps.world;
  gait : Route_legs.gait;
  flee : unit -> unit;  (** Runs from a wild battle, back to the overworld. *)
  fight_trainer : unit -> (unit, Pokemon_checkpoints.Failure.cause) result;
      (** Plays the battle of a trainer who saw the player, from their text to
          the overworld after it. *)
  watch_trainers : bool;
      (** Whether legs across a trainer's sight are walked by
          {!Trainer_crossing}; else they are held as any other, for a save that
          has beaten the maps' trainers. *)
  log : string -> unit;
}

type at = { place : Connected_maps.place; facing : Direction.t option }
(** Where the player stands and faces, as the walk reckons it. *)

val warp_fade_timeout_ms : int
(** 3000: after a hold onto a warp, how long its fade may take to show. *)

val fade_up_timeout_ms : int
(** 5000: how long a warp's fade may take to come back up, and then how long the
    screen may take to stand still in full light (past that the walk goes on).
*)

val door_step_out_ms : int
(** 1000: from a warp's fade coming up, how long the game takes to walk the
    player out of a doorway, ignoring presses. *)

val after_leg_watch_ms : int
(** 500: a message the last step set off shows after the hold. *)

val after_wild_leg_watch_ms : int
(** 3500: a wild battle the last step set off shows after the hold. *)

val walk :
  t ->
  at ->
  Connected_maps.place Grid_planning.Leg.t list ->
  (at, Pokemon_checkpoints.Failure.cause) result
(** Walks the legs from [at], with {!Walk_interrupts.probes} subscribed. Fails
    with [route_unsupported] (an action leg), [leg_blocked], [interrupted],
    [no_warp_fade], [fade_stuck], [trainer_battle], [message_stuck], or as
    [fight_trainer] fails. *)

val step :
  t -> at -> Direction.t -> (at, Pokemon_checkpoints.Failure.cause) result
(** One step toward the direction from [at]: a turn tap if the player faces
    another way, then the D-pad held one tile at a walk, with no interrupt
    watched. For the step onto a tile that sets off a scene (a coord event, as
    the Three Island Bikers' rows): its text shows at once, which a walk's
    message interrupt would press B through, and B answers a scene's question
    NO; the plan's next event plays it. Not in the fork. Fails as
    [step_unsupported] where the press goes nowhere, takes a warp or may meet a
    wild battle. *)
