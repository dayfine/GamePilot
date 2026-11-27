(** From an eye template's match score per frame to blink events: a threshold
    for "eye shut", blinks as dips below it, double blinks grouped, and the NPC
    tick period fitted. {!Blink_grid} places the events on advances.

    Port of the first half of
    [PokemonBDSP/Inference/Rng/PokemonBDSP_BlinkExtraction.{h,cpp}]
    (https://github.com/PokemonAutomation/Arduino-Source; R21: same constants,
    same scans, same float steps). Timestamps are seconds as a [float], the unit
    of the [now] effect; the C++ holds a [WallClock] and converts to seconds
    where it computes. Sentinel returns become options: the C++'s -1 threshold
    and its all-zero {!tick_fit} below three events. *)

type match_sample = { timestamp : float; score : float }
(** [BlinkMatchSample]: one frame's best template match ([match] in the C++). *)

type blink = { seconds : float; depth : float; frames : int }
(** [Blink]: depth-weighted centre (seconds from the origin), deepest closure as
    a fraction of the resting match, and frames below the threshold. *)

type blink_event = { seconds : float; blink_type : Blink_model.blink_type }
(** [BlinkEvent]: one roll's blink. *)

type tick_fit = {
  period_seconds : float;
  rms_ticks : float;
  worst_ticks : float;
}
(** [TickFit]: the period whose tick grid the event gaps fit best, with the RMS
    and worst distance to a whole tick. *)

type frame_gap = {
  start_seconds : float;  (** Timestamp of the last frame before the gap. *)
  stop_seconds : float;  (** Timestamp of the first frame after the gap. *)
}
(** A capture gap between two consecutive frame samples that exceeded the
    maximum safe spacing (in seconds from the stream origin). *)

val default_max_gap_seconds : float
(** 0.065: default maximum spacing between adjacent samples (~2 frames at 30 fps
    or ~4 frames at 60 fps) before a capture gap is flagged. *)

val find_frame_gaps :
  ?origin:float -> ?max_gap_seconds:float -> match_sample list -> frame_gap list
(** Every adjacent pair of samples separated by more than [max_gap_seconds]
    (default {!default_max_gap_seconds}), expressed as seconds from [origin]
    (default the first sample's timestamp). *)

val auto_blink_threshold : match_sample list -> float option
(** How far the match has to fall below its resting level (the median) to count
    as a blink: the middle, on a log scale, of the widest band of 40 thresholds
    from 0.04 to 0.60 over which the blink count stays within one and at 20 or
    more. [None] below 180 s of samples or without such a band. *)

val extract_blinks :
  ?origin:float -> match_sample list -> threshold:float -> blink list
(** Each run of samples deeper than [threshold], centred over the run and two
    samples either side. Seconds count from [origin] (default the first sample).
    Empty below two samples or for a threshold that is not positive. *)

val group_blinks : ?double_blink_seconds:float -> blink list -> blink_event list
(** A second blink arriving within [double_blink_seconds] (default 0.55) is the
    same roll: a double blink. *)

val fit_tick_period :
  ?lowest_seconds:float ->
  ?highest_seconds:float ->
  blink_event list ->
  tick_fit option
(** Scans 401 periods from [lowest_seconds] (default 1.000) to [highest_seconds]
    (default 1.040) for the smallest RMS distance of the event gaps to whole
    ticks; the first wins a tie. The tick is nominally 1.017 s but measures
    1.0197 s on real hardware. [None] below three events. *)
