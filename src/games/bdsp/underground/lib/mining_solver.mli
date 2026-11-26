(** Offline smart solver for the BDSP 13x10 Grand Underground mining minigame.

    Strategy:
    1. If a wanted Mysterious Shard (L prioritized over S) is partially exposed,
       excavate dirt around it with Pickaxe (1 integrity) or Hammer when safe.
    2. If all announced items are already exposed as non-shards, or the sparse
       scan grid is fully cleared with no wanted shard seen, fast-bail by
       collapsing the wall with Hammer hits.
    3. Otherwise run a 3-tile-spaced Hammer scan (shallowest dirt first),
       avoiding known iron bars. *)

(** Next move chosen by the mining solver. *)
type action =
  | Strike of { tool : Mining_wall.tool; col : int; row : int }
      (** Move cursor to [(col, row)], equip [tool], and strike once. *)
  | Bail_collapse
      (** Rule out shards and collapse the wall quickly with Hammer strikes. *)

(** Outcome of playing an offline {!Mining_wall.wall} to completion. *)
type play_result = {
  wall : Mining_wall.wall;  (** Final wall state when finished. *)
  moves : int;  (** Total strikes executed. *)
  bailed : bool;  (** [true] if the solver intentionally collapsed early. *)
  uncovered : Mining_goal.item list;  (** Items completely uncovered and kept. *)
}

val decide :
  goal:Mining_goal.goal ->
  tally:Mining_goal.tally ->
  Mining_wall.observation ->
  action
(** Choose the next {!action} from the current partial observation of the wall. *)

val play_wall :
  goal:Mining_goal.goal ->
  tally:Mining_goal.tally ->
  Mining_wall.wall ->
  play_result
(** Run {!decide} against an offline {!Mining_wall.wall} until it finishes. *)
