(** Walks one leg of a plan: holds a direction for the leg's tiles while
    watching for whatever can stop the player part-way (a wild battle, a
    message, a trainer), each a {!Leg_interrupt.t} the game supplies. A hold is
    an [Effects.race]: when an interrupt is seen, the hold is cancelled, the
    game clears the interrupt, and the rest of the leg is walked. A leg to a
    wall is simply held again, since the wall stops the player on its tile; for
    an open leg, how far the player got is worked out from when the interrupt
    was seen. Ported from the fork's [Pokemon_LegWalker.h].

    Each hold and each interrupt is added to the tracer's open leg, if a tracer
    is given; the caller begins and ends the leg there, as it knows the plan's
    tiles. Progress goes to [log] as ["Leg: ..."] lines, worded as the C++
    walker's. *)

type t = {
  mover : Grid_geometry.Direction.t -> int -> Wire.command list;
      (** The commands that hold the direction for the time in ms, then let go:
          the D-pad or the stick, as the game moves. *)
  interrupts : Leg_interrupt.t list;
      (** Checked in order on every frame: the first seen is the one cleared. *)
  log : string -> unit;
  tracer : Grid_trace.Leg_tracer.t option;
}
(** How a game walks its legs. *)

exception Interrupted_too_often of string
(** A leg or its end was interrupted more often than allowed. The message names
    the count and the leg. *)

val default_max_interruptions : int
(** 5 *)

val walk_leg :
  ?max_interruptions:int ->
  ?hold_watchers:Watch_along.t list ->
  t ->
  Leg_spec.t ->
  Leg_spec.result
(** Walks the leg from a standstill facing its way. [hold_watchers] see every
    hold's frames but stop nothing. Raises {!Interrupted_too_often} past
    [max_interruptions] (default {!default_max_interruptions}). *)

val clear_late_interrupts : ?max_interruptions:int -> t -> watch_ms:int -> int
(** After a leg: waits [watch_ms] for an interrupt the last step set off, which
    shows after the hold has ended, and clears it, until a wait sees none.
    Returns how many it cleared. Raises {!Interrupted_too_often} when one more
    shows after [max_interruptions] in a row. *)
