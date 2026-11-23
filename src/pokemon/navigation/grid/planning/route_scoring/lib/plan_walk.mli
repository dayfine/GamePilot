(** A plan walked from every start tile, nothing interrupting: the ways the walk
    may end, the interruptions it may meet on the way, and how it may fail.
    {!Route_scorer} charges the interruptions. *)

type branch = {
  pos : Tile_pos.t;
  ms : int;
  weight : float;  (** Chance of this branch, the starts equally likely. *)
  sighted : bool;  (** A trainer has seen the player (and been fought). *)
}
(** One way the walk may have gone so far. *)

type interruption = {
  leg : int;  (** The leg's index in the plan. *)
  steps : int;  (** Steps of the leg walked when it happens. *)
  at : Tile_pos.t;
  chance : float;
  cost_ms : int;
  weight : float;  (** The chance of the branch it happens on. *)
}
(** Where an interruption may happen, and what it costs. *)

type t = {
  branches : branch list;  (** By tile, as {!key_of} orders them. *)
  interruptions : interruption list;  (** In the order the walk meets them. *)
  stops : int;  (** Legs that end on a wall. *)
  presses : int;  (** Legs plus taps. *)
  fail : string option;  (** The first way the plan fails, if any. *)
}

val key_of : Tile_pos.t list -> string
(** The tiles as one name, the same for any order of them: sorted by row, then
    column, each as {!Tile_pos.to_string}. *)

val walk :
  Score_map.t ->
  Route_paces.t ->
  Interrupt_model.t ->
  goal:(Tile_pos.t -> bool) ->
  Tile_pos.t list ->
  Scored_leg.t list ->
  t
(** The plan walked from each of the tiles. It fails if a held open leg may
    overshoot onto a hazard, a leg walks into a warp that is not the last leg's
    goal, more tiles than {!Interrupt_model.t.max_spread} are possible after a
    leg, or a walk may end off the goal. *)
