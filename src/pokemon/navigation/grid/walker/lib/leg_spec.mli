(** A leg of a route walk: what to walk ({!t}) and what the walk found
    ({!result}). Ported from the fork's [Pokemon_LegTypes.h]. *)

type t = {
  direction : Grid_geometry.Direction.t;
  tiles : int;
  to_wall : bool;  (** A wall stops the player after the last tile. *)
  tile_ms : int;
      (** How long one tile takes, for this leg's direction and way of moving.
      *)
  stop_on_interrupt : bool;
      (** An open leg stops at its first interrupt, once cleared, instead of
          walking on from an estimate; the caller finds the player again. *)
  stop_if_blocked : bool;
      (** The leg stops when, held again after an interrupt, it is interrupted
          again right away: something on the way, like a sign, interrupts every
          hold, so the leg's end is never reached. *)
  stalled_steps : int list;
      (** The steps (from 1) the game holds the player up a tile before, as
          FireRed does on a step onto a connected map: each makes a hold over it
          a tile longer. *)
  slow_steps : int list;
      (** The steps (from 1) the game moves the player slowly, as FireRed does
          on rock stairs: each takes [slow_step_ms] instead of [tile_ms]. *)
  slow_step_ms : int;
}
(** A straight leg, for a player standing still and facing its way. *)

val make : ?to_wall:bool -> tile_ms:int -> Grid_geometry.Direction.t -> int -> t
(** A leg of [tiles] tiles toward the direction (open unless [to_wall]), that
    walks on after interrupts and has no stalled steps. *)

val to_string : t -> string
(** ["north 6"], ["east 4 (to wall)"]. *)

type result = {
  tiles : int;  (** Tiles walked, which is the leg's unless it stopped. *)
  exact : bool;
      (** Whether [tiles] is certain: an interrupted open leg is an estimate. *)
  interruptions : int;
  stopped : bool;
      (** The leg stopped at an interrupt ([stop_on_interrupt],
          [stop_if_blocked]): the player is somewhere along it. For an open leg
          [tiles] is then how many the interrupt's timing says were walked
          ({!Leg_timing.tiles_before_interrupt}), for the caller to look around;
          for a leg to a wall it is 0. *)
}
(** What walking a leg found. *)
