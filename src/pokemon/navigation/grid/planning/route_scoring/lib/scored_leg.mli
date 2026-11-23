(** One leg of a plan to score ({!Route_scorer}), and how it is walked. *)

(** How a leg is walked. *)
type kind =
  | To_wall  (** Held until the player stops: lands exactly. *)
  | Taps  (** One D-pad tap per tile: lands exactly. *)
  | Open_hold  (** Held for its tiles' time: may land a few tiles off. *)

type t = {
  direction : Direction.t;
  tiles : int;
  kind : kind;
  run : bool;  (** Held at a run (B), not a walk. *)
}

val to_string : t -> string
(** ["west 16 (taps)"], ["south 33 (run to wall)"], ["east 3 (walk, open)"]. *)

val tiles_walked_back : t list -> int
(** Tiles the legs walk back: each leg opposite to a leg before it. A planned
    stop at a wall re-localizes and is not counted, nor are the taps back from
    it right after (running past the goal to a wall and tapping back). *)
