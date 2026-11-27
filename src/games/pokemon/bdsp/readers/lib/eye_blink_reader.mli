(** Reader: eye-blink normalized cross-correlation probe for BDSP RNG.

    Wraps [core.template_ncc@1] with [delivery = Every] so the daemon evaluates
    every captured frame and reports any dropped frames as [gap] notifications.

    Port of
    [SerialPrograms/Source/PokemonBDSP/Inference/Rng/PokemonBDSP_EyeBlinkDetector.{h,cpp}]
    and the Munchlax ROI from
    [SerialPrograms/Source/PokemonBDSP/Programs/RngManipulation/PokemonBDSP_IntroSeedFinder.cpp]
    (https://github.com/PokemonAutomation/Arduino-Source). *)

val munchlax_template_asset : string
(** Repo-relative path to the upstream Munchlax open-eye PNG template
    (["third_party/Packages/Resources/PokemonBDSP/Rng/Munchlax.png"]). *)

val munchlax_probe_id : string
(** Default probe identifier for the Munchlax eye watcher
    (["bdsp_eye_munchlax"]). *)

val munchlax_box : Wire.box
(** Normalized ROI around Munchlax's eye on the BDSP intro cutscene
    ([0.3828, 0.6306, 0.0208, 0.0481], matching [PokemonBDSP_IntroSeedFinder]).
*)

type target = {
  id : string;  (** Unique probe identifier on the wire. *)
  box : Wire.box;
      (** Normalized eye search ROI relative to the game picture. *)
  template : Effects.template_hash;
      (** Uploaded open-eye template hash from {!Effects.upload_template}. *)
}
(** One configured eye-blink watcher target. *)

val munchlax_target : template:Effects.template_hash -> target
(** Builds the preset Munchlax watcher target using {!munchlax_probe_id} and
    {!munchlax_box}. *)

val probes : picture:Wire.box -> target list -> Wire.probe_spec list
(** Builds one [core.template_ncc@1] probe with [delivery = Every] per target,
    clipped to [picture]. *)

val score : Effects.measurements -> string -> float option
(** The [core.template_ncc@1] correlation score ([-1..1], higher means closer to
    the open-eye template) for probe [id] on this frame, or [None] if absent. *)

val dip_depth : resting:float -> float -> float
(** How far [score] falls below [resting] as a fraction in [[0, 1]]:
    [(resting -. score) /. resting], clamped to [[0, 1]] (and [0] when
    [resting <= 0]). Matches [Bdsp_rng.Blink_extraction]. *)

val is_blink_dip : resting:float -> threshold:float -> float -> bool
(** [true] when [resting > 0], [threshold > 0], and
    [dip_depth ~resting score > threshold]. *)
