(** Builds a walker's {!Leg_record}s from what it does, and hands each, as its
    log line, to the tracer's [emit] once the leg ends. A leg still open when
    the next starts, or when its event ends, is emitted with its end unknown. *)

type t

type walk = {
  chunks : int;  (** Chunks of screen movement. *)
  walked_ms : int;  (** The time the direction was held. *)
  wild_battles : int;
  tapped : int option;  (** The taps that moved, for a walk of taps. *)
}
(** What one walk of a leg reports. *)

val create : (string -> unit) -> t
(** A tracer that hands each record's log line to the function. *)

val begin_event : t -> checkpoint:string -> event:string -> unit
(** The legs from here on are [event]'s of [checkpoint]; ends the open leg. *)

val end_event : t -> unit
(** Emits the leg still open, if one is. *)

val begin_leg : t -> Leg_record.plan -> unit
(** A leg starts; the one still open is emitted first. *)

val open_leg : t -> Leg_record.plan option
(** The open leg's plan, if a leg is open. *)

val walked : t -> walk -> unit
(** A walk of the open leg ended. A leg can take several (a walk on to the wall
    after a battle); they add up. Nothing when no leg is open. *)

val interrupted : t -> Leg_record.Interrupt.t -> unit
(** Something stopped or delayed the open leg. *)

val end_leg :
  t -> ?note:string -> Route_tile.t list -> Leg_record.End_known.t -> unit
(** The open leg ended on the tiles, known as the second argument says; emits
    it. Nothing when no leg is open. *)
