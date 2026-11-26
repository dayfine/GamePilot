(** Pure offline simulator of the BDSP Grand Underground 13x10 mining wall.

    Models the 49-point wall integrity pool, Hammer (3x3, cost 2) and Pickaxe
    (5-tile cross, cost 1) damage kernels, unbreakable iron bars, and the
    partial observation available to a frame reader. *)

(** Digging tool selected in the minigame. *)
type tool =
  | Hammer  (** Red Hammer: 3x3 damage kernel, costs 2 wall integrity. *)
  | Pickaxe  (** Blue Pickaxe: 5-tile cross damage kernel, costs 1 integrity. *)

type buried_item = {
  id : int;  (** Unique item identifier within the wall. *)
  kind : Mining_goal.item;  (** Shard S, Shard L, or Other. *)
  cells : (int * int) list;  (** All [(col, row)] tiles occupied by the item. *)
}
(** One buried treasure placed on the 13x10 wall. *)

(** Hidden layer underneath a wall tile once its dirt is cleared. *)
type cell_content =
  | Empty  (** Plain cleared brown rock. *)
  | Iron  (** Unbreakable metallic bar that wastes integrity if struck. *)
  | Item of int  (** Part of buried item [id]. *)

(** What a frame reader can observe on one cell of the 13x10 wall. *)
type visible_cell =
  | Covered of int  (** Remaining dirt layers ([1..6]). *)
  | Clear_empty  (** Fully cleared empty rock. *)
  | Clear_iron  (** Exposed unbreakable iron bar. *)
  | Clear_item of { id : int; kind : Mining_goal.item }
      (** Exposed tile of an item peeking through cleared dirt. *)

type wall
(** Complete hidden + visible state of an offline 13x10 mining wall. *)

type observation = {
  cols : int;  (** Grid width (13). *)
  rows : int;  (** Grid height (10). *)
  integrity : int;  (** Remaining wall integrity (0..49). *)
  collapsed : bool;  (** [true] once integrity hits 0. *)
  announced_items : int;  (** Item count announced at wall start (2..4). *)
  grid : visible_cell array array;  (** Indexed as [grid.(row).(col)]. *)
  uncovered_ids : int list;  (** Item IDs completely cleared of dirt. *)
}
(** Snapshot of the 13x10 mining wall visible to a solver or frame reader. *)

val cols : int
(** Width of the BDSP mining grid (13 columns). *)

val rows : int
(** Height of the BDSP mining grid (10 rows). *)

val max_integrity : int
(** Starting wall integrity pool (49 points). *)

val hammer_cost : int
(** Integrity points deducted per Hammer strike (2). *)

val pickaxe_cost : int
(** Integrity points deducted per Pickaxe strike (1). *)

val tool_cost : tool -> int
(** Integrity cost of striking once with [tool]. *)

val in_bounds : col:int -> row:int -> bool
(** [true] when [(col, row)] lies inside the 13x10 grid. *)

val make :
  dirt:int array array ->
  iron:(int * int) list ->
  items:buried_item list ->
  (wall, string) result
(** Build a wall from a [rows x cols] dirt-layer matrix, iron bar coordinates,
    and buried items. Returns [Error] if dimensions or coordinates are invalid.
*)

val generate : seed:int -> items:Mining_goal.item list -> wall
(** Deterministic synthetic wall generator for offline solver benchmarks. *)

val observe : wall -> observation
(** Project [wall] to the partial observation visible to a solver. *)

val strike : wall -> tool:tool -> col:int -> row:int -> wall
(** Apply one tool hit. No-op if the wall has already collapsed or all items are
    uncovered. *)

val integrity : wall -> int
(** Remaining wall integrity points. *)

val is_finished : wall -> bool
(** [true] when collapsed or every buried item is completely uncovered. *)

val uncovered_items : wall -> Mining_goal.item list
(** Items completely cleared of dirt (kept even after collapse). *)

val all_items : wall -> buried_item list
(** All items buried in [wall], uncovered or not. *)
