(** The log lines a route walk writes, shared by the games' walkers so every
    game's log reads the same and PokemonSimulation can draw any run's routes
    from it (its [run_trace.py] and [leg_trace.py] read them back):

    {v
    [Route] To the grass: plan from Route 202 (15, 25), Route 202 (16, 25): east 15 (to wall) to Route 202 (23, 25), Route 202 (30, 26); north 5 (to wall) to Route 202 (23, 24)
    [Route] Leg 1/2: east 15 (to wall) to Route 202 (23, 25), Route 202 (30, 26)
    [Route] To the grass: east 15 (to wall): ended at Route 202 (23, 25) (walked).
    [Route] To the grass: north 5 (to wall): stopped early after about 2 tiles, at Route 202 (23, 23); planning again.
    [Route] To the grass: found again at Route 202 (22, 24), after 2 hold(s).
    [Route] To the grass: arrived at Route 202 (23, 24).
    v}

    A position is a set of tiles: BDSP plans from every tile the player may be
    on, FRLG from the one it is on. The text matches the C++ walkers' word for
    word (the fork's Pokemon/Navigation/Grid/Trace/Pokemon_RouteLog.{h,cpp}). The functions return a line without the tag, which {!tag} holds; the
    caller logs it. *)

val tag : string
(** ["[Route] "], the prefix of every route line. *)

(** How the end of a walked leg is known. *)
type end_basis =
  | Walked  (** Walked as planned, or seen. *)
  | Assumed  (** Taken to have ended as planned after an interrupt. *)
  | Unknown  (** Stopped somewhere on the way. *)

val basis_name : end_basis -> string
(** ["walked"], ["assumed"], ["unknown"]. *)

val plan_line :
  label:string -> from:Route_tile.t list -> Route_leg.planned list -> string
(** ["<label>: plan from <tiles>: <leg> to <tiles>; <leg> to <tiles>"] on one
    line; ["<label>: plan from <tiles>:"] with no legs. *)

val leg_line : number:int -> count:int -> Route_leg.planned -> string
(** ["Leg <number>/<count>: <leg> to <tiles>"], as the leg starts. *)

val leg_end_line :
  label:string ->
  ?why:string ->
  Route_leg.t ->
  at:Route_tile.t list ->
  end_basis ->
  string
(** ["<label>: <leg>: ended at <tiles> (<basis>)."], or with [why]
    ["... (<basis>: <why>)."]. *)

val replan_line :
  label:string -> Route_leg.t -> what:string -> at:Route_tile.t list -> string
(** ["<label>: <leg>: <what>, at <tiles>; planning again."]: the leg stopped
    short where the player was seen, and the route is planned again from there.
*)

val found_line : label:string -> at:Route_tile.t list -> holds:int -> string
(** ["<label>: found again at <tiles>, after <holds> hold(s)."]: after a stop
    where the player wasn't seen, holds to walls found them. *)

val trainer_line : label:string -> who:string -> at:Route_tile.t list -> string
(** ["<label>: <who> stopped us about <tiles>."] *)

val arrived_line : label:string -> at:Route_tile.t list -> string
(** ["<label>: arrived at <tiles>."] *)
