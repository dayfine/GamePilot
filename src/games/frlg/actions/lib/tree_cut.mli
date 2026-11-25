(** What a Cut does to the story's world and position: the fork's [tree_cut]
    (AutoStory/PokemonFRLG_AutoStoryBoulders), which the fork's run state
    applies after its [cut_tree] event, and [regrow_on_warp] around every step.
*)

val cut :
  Frlg_overworld.Frlg_steps.world ->
  Checkpoints.Pose.observed ->
  Grid_maps.Direction.t ->
  Frlg_overworld.Frlg_steps.world * Checkpoints.Pose.observed
(** From where the player stood facing the tree that way: the world with the
    tree's gate open ({!Frlg_overworld.Frlg_steps.with_tree_cut}; unchanged when
    no cut tree is there) and the player on the tree's tile, facing it. *)

val regrown :
  Frlg_overworld.Frlg_steps.world ->
  before:string option ->
  after:string option ->
  Frlg_overworld.Frlg_steps.world
(** After a step from map [before] to map [after]: every cut tree back when the
    map changed (a cut tree's flag is temporary). *)
