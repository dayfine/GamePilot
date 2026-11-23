(** Something that stops the player part-way through a leg: a wild battle, a
    message, a trainer. The game supplies each; the walker watches for all of
    them while it holds a direction. *)

type t = {
  name : string;  (** For the log: ["a battle"]. *)
  kind : Grid_trace.Leg_record.Interrupt.t;  (** For the leg record. *)
  seen : Effects.measurements -> bool;
      (** The reader: the interrupt's screen is up on this frame. *)
  detection_delay_ms : int;
      (** How long after the step that set it off [seen] holds. The games only
          interrupt between steps, so from this the walker works out how many
          tiles of an open leg were walked. *)
  clear : unit -> unit;
      (** Clears it, leaving the player standing on the overworld, on the same
          tile and facing the same way. Runs effects. *)
}
