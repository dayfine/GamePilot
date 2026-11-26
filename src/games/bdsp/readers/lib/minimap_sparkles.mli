(** Reader: Grand Underground minimap orange dig-spot sparkles and pink player
    dot position along the three corridors of the central Hideaway ring.

    Measured from Console A captures ([run-24/frames/000001.jpg],
    [run-39/frames/000024.jpg], [run-42/frames/000300.jpg],
    [run-46/frames/000025.jpg]):
    - Orange sparkle diamonds: RGB [(200..255, 110..215, 0..80)].
    - Pink player dot: RGB [(170..255, 40..145, 100..210)]. Each of the three
      ring corridors is split into [buckets_per_corridor] (4) ordered sub-boxes
      so the runner can sprint straight to each sparkle's bucket without
      stepping tile by tile. *)

(** The three corridors on the right half of the central Hideaway ring. *)
type corridor =
  | Bottom_east  (** Horizontal corridor East of the South doorway. *)
  | East_vertical  (** Vertical corridor along the East outer wall. *)
  | Top_east  (** Horizontal corridor West from NE corner to North doorway. *)

type target = {
  corridor : corridor;
  bucket : int;  (** Ordered 0..3 along the corridor's travel direction. *)
}
(** One active dig-spot bucket detected on the minimap. *)

type nearby = {
  bottom_east : bool;
      (** At least one orange sparkle in the bottom-East corridor. *)
  east_vertical : bool;
      (** At least one orange sparkle along the East vertical corridor. *)
  top_east : bool;  (** At least one orange sparkle in the top-East corridor. *)
  targets : target list;
      (** Ordered list of active sparkle buckets to sprint to. *)
  player : target option;
      (** Current corridor and bucket of the pink player dot, if inside the
          ring. *)
}
(** Active nearby dig-spot and player-position summary from the minimap. *)

val buckets_per_corridor : int
(** Number of sub-buckets per corridor (4). *)

val none : nearby
(** No sparkles and no player bucket read. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** All orange-sparkle and pink-player-dot [color_count_probe] specs across the
    three ring corridors on the top-left minimap. *)

val full_map_probes : picture:Wire.box -> Wire.probe_spec list
(** Orange-sparkle [color_count_probe] specs across the three ring corridors on
    the unobstructed full-sized Underground map ([Y -> A]). *)

val read : Effects.measurements -> nearby
(** Read peak-merged active sparkle buckets and current player bucket from the
    top-left minimap measurements. *)

val read_full_map : Effects.measurements -> nearby
(** Read peak-merged active sparkle buckets from the full-sized Underground map
    ([Y -> A]) measurements. *)

val debug_full_map : Effects.measurements -> string
(** Format raw per-bucket orange pixel shares for all 12 full-map buckets. *)

val any : nearby -> bool
(** [true] when at least one sparkle bucket is active. *)

val to_string : nearby -> string
(** Short summary, e.g. ["bottom_east[1], top_east[2]"] or ["none"]. *)
