(** How a story scene ({!Scene_machine}) fails, worded as
    PokemonLZA_AutoStorySceneMachine.cpp's [scene_outcome] and its timeout
    ([plza/lean]). [label] names the scene ("scene"); [expected] is what would
    have ended it ("the controls hint, the party bar or the A prompt"). *)

val timed_out :
  label:string -> seconds:int -> expected:string -> Engine_run.Failure.cause
(** [scene_timeout]: not done within [seconds]. *)

val ended_in_control :
  label:string -> hold_ms:int -> expected:string -> Engine_run.Failure.cause
(** [scene_ended_in_control]: control held [hold_ms] with nothing busy where a
    choice or a battle was due. *)

val never_started :
  label:string -> window_ms:int -> expected:string -> Engine_run.Failure.cause
(** [scene_never_started]: the HUD up and no scene for the start window. *)
