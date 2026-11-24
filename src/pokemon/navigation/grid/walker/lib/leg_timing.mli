(** How long a leg is held, and how far an interrupted hold got. *)

val hold_ms : Leg_spec.t -> int -> int
(** [hold_ms leg tiles]: how long to hold for the last [tiles] tiles of [leg].
    An open leg lets go half a tile before the last step would end, so the step
    under way finishes and no other starts; a leg to a wall is held two tiles
    longer than it takes. Each stalled step among those tiles adds a tile, each
    slow step its extra time. *)

val tiles_before_interrupt :
  Leg_spec.t -> elapsed_ms:int -> detection_delay_ms:int -> remaining:int -> int
(** How many tiles an open leg had walked when an interrupt was seen
    [elapsed_ms] into its hold, given the interrupt's detection delay. Steps end
    a whole number of tiles into the hold, so this rounds to the nearest, from 0
    up to [remaining]. *)
