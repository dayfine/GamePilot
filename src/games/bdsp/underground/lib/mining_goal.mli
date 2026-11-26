(** Goal setting and progress tally for BDSP Grand Underground shard farming.

    Ramanas Park uses 14 slates total per version; each slate trades for either
    3 Mysterious Shard S or 1 Mysterious Shard L. *)

(** Item classes relevant to shard farming. *)
type item =
  | Shard_s  (** Mysterious Shard S (3 trade for 1 Ramanas Park slate). *)
  | Shard_l  (** Mysterious Shard L (1 trades for 1 Ramanas Park slate). *)
  | Other  (** Any non-shard treasure (spheres, stones, fossils, boxes). *)

(** Target condition for stopping a Grand Underground farming session. *)
type goal =
  | Slates of int
      (** Target number of Ramanas Park slates ([shard_l + shard_s / 3]). *)
  | Shards of { shard_s : int; shard_l : int }
      (** Explicit minimum counts for each shard size. *)

(** Cumulative counts across a farming session. *)
type tally = {
  shard_s : int;  (** Total Mysterious Shard S collected. *)
  shard_l : int;  (** Total Mysterious Shard L collected. *)
  digs : int;  (** Total mining walls completed. *)
  walls_bailed : int;  (** Walls collapsed early after ruling out shards. *)
}

(** Which shard sizes the mining solver should prioritize. *)
type priority =
  | Large_first  (** Prefer Shard L, also excavate Shard S. *)
  | Small_only  (** Only excavate Shard S (Shard L goal already met). *)
  | Large_only  (** Only excavate Shard L (Shard S goal already met). *)

val ramanas_all_slates : goal
(** All 14 Ramanas Park slates for one game version. *)

val small_per_slate : int
(** Number of Mysterious Shard S equivalent to one slate (3). *)

val empty_tally : tally
(** Zeroed starting tally for a new session. *)

val slate_equivalents : tally -> int
(** Complete slates purchasable from the collected shards. *)

val is_met : goal -> tally -> bool
(** [true] when [tally] satisfies [goal]. *)

val remaining_slates : goal -> tally -> int
(** Slates still needed for a [Slates] goal, or [0] if met (for [Shards], the
    sum of remaining large shards and ceiling-slates of small shards). *)

val priority : goal -> tally -> priority
(** Which shard sizes are still useful to excavate given the current tally. *)

val wants_item : goal -> tally -> item -> bool
(** [true] when [item] advances [goal] given [tally]. *)

val record_dig : tally -> bailed:bool -> item list -> tally
(** Update [tally] with one completed wall's uncovered items and bail flag. *)
