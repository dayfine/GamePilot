(** How interruptions on a walk are charged ({!Route_scorer}). The game sets the
    chances and costs. *)

type t = {
  encounter_per_tile : float;
  encounter_ms : int;  (** A wild battle run from. *)
  wanderer_per_tile : float;
  wanderer_ms : int;  (** Waiting for them to move on. *)
  trainer_ms : int;  (** A trainer battle. *)
  replan_ms : int;  (** A stop and a new plan. *)
  max_recoveries : int;
      (** Most recoveries in a row before the plan counts as stuck. *)
  max_spread : int;
      (** Most tiles the player may be on at once, before a plan is too loose.
      *)
}

val none : t
(** Nothing interrupts and nothing is charged; at most 3 recoveries in a row and
    32 tiles at once. *)
