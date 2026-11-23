(** Cutting the tree the player faces: a turn toward it, A, YES to "use CUT?",
    then the talk settle while the tree falls. The fork's [cut_tree] field step;
    the plan's route has already brought the player next to the tree. *)

val turn_hold_ms : int
(** A D-pad press this short only turns the player: 40 ms. *)

val cut : log:(string -> unit) -> Grid_maps.Direction.t -> unit
(** Fails as [cut_no_prompt] (no Cut user, or no tree there). *)
