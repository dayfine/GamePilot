(** Cutting the tree the player faces: a turn toward it, A, YES to "use CUT?",
    the talk settle while the tree falls, then one step tap onto the tree's tile
    (the fork's [step_once], a walking tap). The fork's [cut_tree] event
    (AutoStory/PokemonFRLG_AutoStoryEvents); the plan's route has already
    brought the player next to the tree. The player ends on the tree's tile,
    whose gate {!Checkpoint_game} opens for the planner until the next map
    change, as the fork's [tree_cut] and [regrow_on_warp]. *)

val turn_hold_ms : int
(** A D-pad press this short only turns the player: 40 ms. *)

val cut : log:(string -> unit) -> Grid_geometry.Direction.t -> unit
(** Fails as [cut_no_prompt] (no Cut user, or no tree there). *)
