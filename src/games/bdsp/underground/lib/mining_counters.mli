(** Structured item and session counters for BDSP Grand Underground farming.

    Tracks collected treasures by kind (Mysterious Shard S/L, spheres, evolution
    stones, fossils, statue boxes, other) alongside loop statistics (cycles,
    doorway refreshes, empty-corridor fast-skips, digs, fast-bails, and escaped
    wild battles) for live Watch Page reporting and end-of-run summaries. *)

(** Detailed treasure categories dug up in the Grand Underground. *)
type treasure =
  | Shard_s  (** Mysterious Shard S (3 = 1 Ramanas Park slate). *)
  | Shard_l  (** Mysterious Shard L (1 = 1 Ramanas Park slate). *)
  | Sphere  (** Prism/Pale/Red/Blue/Green Sphere. *)
  | Evolution_stone  (** Fire, Water, Thunder, Leaf, Moon, Sun, Dawn, Dusk, Shiny Stone. *)
  | Fossil  (** Skull, Armor, Helix, Dome, Old Amber, Root, Claw Fossil. *)
  | Statue_box  (** Pretty or Gorgeous Stone Box. *)
  | Other_treasure  (** Heart Scale, Hard Stone, Plate, Revive, etc. *)

(** Cumulative counters for a Grand Underground farming run. *)
type t = {
  cycles : int;  (** Completed loop cycles. *)
  refreshes : int;  (** Hideaway doorway bounces performed. *)
  skipped_corridors : int;  (** Cycles skipped when minimap showed no nearby sparkles. *)
  digs : int;  (** Mining walls entered and completed. *)
  walls_bailed : int;  (** Walls collapsed early after ruling out wanted shards. *)
  battles_escaped : int;  (** Unexpected wild battles escaped cleanly. *)
  shard_s : int;  (** Mysterious Shard S collected. *)
  shard_l : int;  (** Mysterious Shard L collected. *)
  spheres : int;  (** Spheres collected. *)
  stones : int;  (** Evolution stones collected. *)
  fossils : int;  (** Fossils collected. *)
  statue_boxes : int;  (** Stone boxes collected. *)
  other_treasures : int;  (** Other items collected. *)
}

val empty : t
(** Zeroed starting counters for a new run. *)

val record_cycle : t -> t
(** Increment [cycles] by 1. *)

val record_refresh : t -> t
(** Increment [refreshes] by 1. *)

val record_skipped_corridor : t -> t
(** Increment [skipped_corridors] by 1. *)

val record_battle_escaped : t -> t
(** Increment [battles_escaped] by 1. *)

val record_dig : t -> bailed:bool -> treasure list -> t
(** Record one completed wall, its bail flag, and any uncovered treasures. *)

val to_tally : t -> Mining_goal.tally
(** Project shard/dig/bail counts into a {!Mining_goal.tally}. *)

val format_summary : goal:Mining_goal.goal -> t -> string
(** Format a concise single-line counter summary suitable for Watch Page logs. *)
