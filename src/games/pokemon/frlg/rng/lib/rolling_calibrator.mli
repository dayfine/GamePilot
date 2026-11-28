(** 10-attempt rolling-average RNG timing calibrator.

    Port of the 10-attempt rolling calibration history from
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_RngCalibration.cpp]
    (https://github.com/PokemonAutomation/Arduino-Source).

    Deliberate differences from the C++:
    - Seed calibration is tracked in milliseconds ([boot_offset_ms]) using
      {!Rng_timings.switch}'s frame duration ([1000.0 / 59.999977 ≈ 16.6667 ms])
      rather than fractional seed-table frame indices, so one cold-boot jitter
      spike nudges the next attempt by [1 / N] instead of jumping 100%.
    - Extreme outliers ([abs seed_delta_frames > max_seed_delta_frames] or
      [abs advance_delta > max_advance_delta]) are rejected so a Summary OCR
      misread cannot poison the rolling window.
    - [ingame_offset] is averaged as a single combined advance offset; odd
      Switch parity is split into [csf_offset] (1 adv/frame) downstream when
      computing timings. *)

type sample = {
  implied_boot_offset_ms : float;
      (** Implied ideal [boot_offset_ms] for this attempt:
          [float_of_int used_boot_offset_ms -. float_of_int seed_delta_frames *.
           frame_duration_ms]. *)
  implied_ingame_offset : int;
      (** Implied ideal [ingame_offset] for this attempt:
          [used_ingame_offset - advance_delta]. *)
}
(** One accepted calibration observation in the rolling window. *)

type estimate = {
  boot_offset_ms : int;
      (** Rounded mean of [implied_boot_offset_ms] across the rolling window. *)
  ingame_offset : int;
      (** Rounded mean of [implied_ingame_offset] across the rolling window. *)
  sample_count : int;
      (** Number of samples currently in the rolling window ([1..max_history]).
      *)
}
(** Next timing offsets computed from the rolling window. *)

type t
(** Immutable rolling calibration history capped at [max_history] samples. *)

(** Result of feeding one miss observation into {!record}. *)
type outcome =
  | Accepted of { state : t; estimate : estimate }
      (** Observation was within outlier bounds; [state] holds the updated
          rolling window and [estimate] gives the new rounded means. *)
  | Rejected_outlier of { seed_delta_frames : int; advance_delta : int }
      (** Observation exceeded {!max_seed_delta_frames} or {!max_advance_delta}
          and was ignored without modifying the window. *)

val max_history_length : int
(** Default rolling window cap ([10]). *)

val max_seed_delta_frames : int
(** Maximum accepted [abs seed_delta_frames] ([30]); larger misses are rejected
    as outliers. *)

val max_advance_delta : int
(** Maximum accepted [abs advance_delta] ([50]); larger misses are rejected as
    outliers. *)

val min_parity_lock_samples : int
(** Minimum number of recent samples ([3]) required to declare a parity lock. *)

val default_frame_duration_ms : float
(** Frame duration in ms used to convert [seed_delta_frames] to milliseconds
    ({!Rng_timings.switch}[.frame_duration_ms], [≈ 16.6667 ms]). *)

val create :
  ?max_history:int ->
  ?frame_duration_ms:float ->
  ?max_seed_delta:int ->
  ?max_advance_delta:int ->
  unit ->
  t
(** Creates an empty rolling calibrator with configurable window cap (clamped to
    at least [1]), frame duration, and outlier thresholds. *)

val empty : t
(** Empty rolling calibrator with default settings ([max_history = 10], Switch
    frame duration, outlier bounds [30] frames / [50] advances). *)

val count : t -> int
(** Number of accepted samples currently retained in the rolling window. *)

val samples : t -> sample list
(** Accepted samples in the rolling window, newest first. *)

val parity_locked : t -> bool
(** [true] when the target advance appears unreachable on a 2-advance-per-frame
    console: no sample in the window has hit [advance_delta = 0], at least
    {!min_parity_lock_samples} recent samples all missed by [±1] advance, and
    the used [ingame_offset] values strictly bracket both sides (every [-1]
    observation used a smaller [ingame_offset] than every [+1] observation). *)

val reset : t -> t
(** Clears all retained samples and advance observations while keeping the
    calibrator's configuration. *)

val record :
  t ->
  used_boot_offset_ms:int ->
  used_ingame_offset:int ->
  seed_delta_frames:int ->
  advance_delta:int ->
  outcome
(** Validates the miss deltas against the outlier bounds, adds the implied ideal
    offsets to the rolling window (dropping the oldest sample once the window
    exceeds [max_history]), and returns the new rounded mean {!estimate}. *)
