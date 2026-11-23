(** What the leg planner weighs: tiles, turns, and legs that end in the open,
    where the player could keep going. Such a leg has to be timed, and where an
    interruption leaves the player is a guess. *)

type t = {
  per_tile : int;
  per_turn : int;  (** Extra for a step in a new direction. *)
  per_open_stop : int;  (** Extra for ending a leg in the open. *)
  per_open_wild_stop : int;
      (** Extra again when that leg has a wild step ({!Leg.step.wild}), where an
          interruption is likely. *)
  per_open_connection_stop : int;
      (** Extra when that leg crosses a map connection, where a map load's stall
          can shift the stopping tile unless it runs to a wall. *)
}

val default : t
(** A tile 1, a turn 2, an open stop 8, and nothing extra for a wild or
    connection open stop. *)
