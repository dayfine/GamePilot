(** Loads player open-eye PNG templates and optional post-intro frame capture
    settings from environment variables or committed repository assets. *)

type loaded = {
  player_eye_png : string;
      (** Raw PNG bytes of the player's open eye facing South. *)
  chamber_eye_png : string;
      (** Raw PNG bytes of the player's open eye inside a Ramanas Park Mystery
          Space (defaults to [player_eye_png]). *)
  frame_dir : string option;
      (** Optional directory from [GAMEPILOT_BDSP_FRAME_DIR] for saving
          post-intro battle frames. *)
}
(** Template bytes and capture settings resolved from the local environment. *)

val load : unit -> (loaded, string) result
(** Resolves the player eye template from [GAMEPILOT_BDSP_PLAYER_EYE_PNG] or
    [src/games/pokemon/bdsp/assets/player_eye.png], the optional chamber eye
    override from [GAMEPILOT_BDSP_CHAMBER_EYE_PNG], and
    [GAMEPILOT_BDSP_FRAME_DIR]. *)
