(** Walking one direction on a {!Robust_model}: to the wall, or so many tiles,
    and what the walk meets on the way. *)

type 'state wall_hit = {
  stop : 'state;  (** Where the player stops. *)
  tiles : int;  (** Tiles travelled; a ledge hop counts 2. *)
  held : bool;  (** The player stays on [stop] however long they hold on. *)
}

val max_steps_to_wall : int
(** Most steps a leg to a wall may take: 1024. No map is this long; a model
    whose steps loop (edge connections that come back round, or a model bug)
    would otherwise slide forever. *)

val to_wall : 'state Robust_model.t -> 'state -> Direction.t -> 'state wall_hit
(** Walks that way until the player is stopped. A walk that is not stopped
    within {!max_steps_to_wall} steps is not held. *)

type 'state stepped = {
  last : 'state;  (** Where the walk ends. *)
  wild : int;  (** Wild places entered. *)
  wander : int;  (** Places entered where someone wanders. *)
  along_wander : bool;  (** Two wander places in a row, the start among them. *)
}

val tiles :
  'state Robust_model.t -> 'state -> Direction.t -> int -> 'state stepped option
(** Steps up to that many tiles that way, stopping early where the player is
    held; [None] if a step is stopped where the player is not held. *)

val prefixes :
  'state Robust_model.t ->
  'state ->
  Direction.t ->
  most:int ->
  by_tiles:bool ->
  'state stepped option array
(** {!tiles} for each count from 1 to [most] (element [n - 1] for [n]), in one
    walk. [by_tiles] (a timed hold) counts tile distance, a ledge hop 2;
    otherwise (tapped) it counts presses, a ledge hop 1. *)
