(** One structured record per walked leg, shared by the games' walkers and their
    simulations, so a console run's route can be compared leg by leg with the
    simulation's (PokemonSimulation's [leg_trace.py] reads it). Each leg is one
    log line beside the free-text route lines:

    {v
    [Leg] {"checkpoint":"00.04","chunks":1,"dir":"north","end":[["Route 201",57,4]],...}
    v}

    A record holds what was planned (direction, tiles, how the leg ends and the
    tiles it may end on), what was measured (taps that moved, the walk's moved
    chunks and held time), where the leg ended and how that is known, and what
    interrupted it. The JSON matches the C++ walkers' byte for byte: compact,
    keys sorted. *)

val tag : string
(** ["[Leg] "], the prefix of a record's log line. *)

(** How a leg is planned to end. *)
module End_kind : sig
  type t =
    | Open  (** Timed or tapped into the open. *)
    | Wall  (** Held until a wall stops it. *)
    | Tile  (** Counted taps onto an exact tile. *)

  val name : t -> string
  (** ["open"], ["wall"], ["tile"]. *)
end

(** How the end of a leg is known. *)
module End_known : sig
  type t =
    | Wall  (** A wall stopped the walk. *)
    | Fade  (** A warp's fade or banner ended it. *)
    | Dialogue  (** A dialogue stopped it. *)
    | Counted  (** Taps that moved, counted against the map. *)
    | Dead_reckoned  (** Taken to have ended as planned. *)
    | Seen  (** Stopped short, where the walker found itself. *)
    | Unknown  (** Not known: the leg was cut off. *)

  val name : t -> string
  (** ["wall"], ["fade"], ["dialogue"], ["counted"], ["dead_reckoned"],
      ["seen"], ["unknown"]. *)
end

(** What stopped or delayed a leg on the way. *)
module Interrupt : sig
  type t =
    | Wild_battle
    | Trainer
    | Scene
    | Dialogue
    | Blocked  (** Someone the map lacks stood in the way. *)

  val name : t -> string
  (** ["wild_battle"], ["trainer"], ["scene"], ["dialogue"], ["blocked"]. *)
end

type plan = {
  direction : Grid_maps.Direction.t;
  tiles : int;
  end_kind : End_kind.t;
  ends : Route_tile.t list;
      (** Every tile the leg may end on; [[]] where the plan does not say. *)
}
(** What a leg is planned to do. *)

val plan : Grid_maps.Direction.t -> int -> End_kind.t -> plan
(** A plan that does not say where it ends. *)

type t = {
  checkpoint : string;
  event : string;
  leg : int;  (** From 1, counted through the event, replans included. *)
  plan : plan;
  moved : int option;  (** The taps that moved, where the leg counts them. *)
  chunks : int;  (** Chunks of screen movement the leg's walks report. *)
  walked_ms : int;  (** The time the direction was held. *)
  end_tiles : Route_tile.t list;
      (** The tiles the leg ended on, as the walker knows them. *)
  known : End_known.t;
  interrupts : Interrupt.t list;
  note : string option;
      (** Why the leg ended other than as planned (["replan"], ["warp"]). *)
}

val to_json : t -> string
(** The record as one line of compact JSON, keys sorted. *)

val to_line : t -> string
(** {!tag} and the record's JSON. *)

val plan_of_leg_line : string -> plan option
(** A {!Route_log.leg_line} read back:
    ["Leg 1/2: east 15 (to wall) to <tiles>"]. A warp leg ends at its tiles, as
    a tile leg. [None] for any other line, and for a leg that is not a walk. *)
