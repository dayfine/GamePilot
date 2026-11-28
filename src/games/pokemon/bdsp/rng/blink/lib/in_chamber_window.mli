(** Pure blink-window preparation, suffix-sliding [1PK] re-identification, and
    diagnostic formatting for {!In_chamber_reidentifier}.

    Converts extracted player blink events and capture gaps into
    {!Bdsp_rng.Mixed_reidentifier} requests, retries suffixes when a leading
    glitched blink causes a zero-candidate failure, computes window-trim cutoffs
    to discard poisoned prefixes, and formats compact blink summaries for error
    messages. *)

type reid_attempt = {
  result : Bdsp_rng.Mixed_reidentifier.result;
      (** Raw {!Bdsp_rng.Mixed_reidentifier.reidentify} result. *)
  blinks : Bdsp_rng.Mixed_reidentifier.player_blink list;
      (** Player blinks passed to the re-identifier. *)
  unknown_ticks : int list;
      (** Player tick indices marked unknown because of capture gaps. *)
  last_ev_s : float;
      (** Timestamp (seconds from stream origin) of the last kept blink. *)
}
(** Inputs and outcome of a single [1PK] re-identification attempt. *)

(** Outcome of evaluating an observed blink window (including suffix recovery).
*)
type evaluation =
  | Matched of {
      result : Bdsp_rng.Mixed_reidentifier.result;
          (** Unique [1PK] re-identification match. *)
      last_ev_s : float;
          (** Timestamp (seconds from stream origin) of the last kept blink. *)
    }  (** Unique [1PK] match locked on the full sequence or a clean suffix. *)
  | Ambiguous of reid_attempt
      (** Two or more candidate positions matched the full sequence or a valid
          suffix; collecting more blinks may disambiguate. *)
  | No_match of reid_attempt
      (** Zero candidate positions matched the full sequence or any suffix of at
          least [min_blinks] events. *)

val build_reid_inputs :
  tick_seconds:float option ->
  gaps:Bdsp_rng.Blink_extraction.frame_gap list ->
  Bdsp_rng.Blink_extraction.blink_event list ->
  Bdsp_rng.Mixed_reidentifier.player_blink list * int list * float
(** Builds [(blinks, unknown_ticks, last_ev_s)] relative to the first event in
    [events], dropping pre-gap blinks and clearing single/double type on
    post-gap single blinks. *)

val evaluate :
  base_state:Bdsp_rng.Xorshift128.state ->
  search_min:int ->
  search_max:int ->
  min_blinks:int ->
  tick_seconds:float option ->
  order_swap_tolerance:float ->
  gaps:Bdsp_rng.Blink_extraction.frame_gap list ->
  Bdsp_rng.Blink_extraction.blink_event list ->
  evaluation
(** Runs [1PK] re-identification on [events]. On a zero-candidate failure,
    retries suffixes dropping [1, 2, ...] leading events while at least
    [min_blinks] remain, returning {!Matched} immediately if a suffix uniquely
    locks. *)

val trim_cutoff_seconds :
  origin:float -> Bdsp_rng.Blink_extraction.blink_event list -> float option
(** Absolute timestamp (seconds) midway between the oldest half of [events] and
    the remaining recent half, used to discard a poisoned prefix while keeping
    recent samples intact. [None] when fewer than two events exist. *)

val format_diagnostics :
  blinks:Bdsp_rng.Mixed_reidentifier.player_blink list ->
  unknown_ticks:int list ->
  gaps:Bdsp_rng.Blink_extraction.frame_gap list ->
  string
(** Formats a compact diagnostic summary of observed blinks (count, [S]/[D]/[?]
    types, consecutive intervals in seconds, unknown tick indices, and capture
    gap count). *)
