(** Connected-component labeling and uncovered-item inference for the 13x10 BDSP
    Grand Underground mining grid. *)

open Bdsp_underground

val label_and_infer_uncovered : Mining_wall.visible_cell array array -> int list
(** Assign a distinct item ID to each 4-connected component of exposed
    [Clear_item] cells in place, and return the IDs of components (>= 2 cells)
    with no remaining covered neighbors. *)
