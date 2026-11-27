(** Re-derives the advance of the newest blink from the recovered state, so a
    clock that has drifted while holding position is set right: the ticks
    between the anchor watcher's newest blinks are matched against the rolls
    near where the clock says they were.

    Port of [reanchor_absolute] in
    [PokemonBDSP/Programs/RngManipulation/PokemonBDSP_BlinkRecovery.{h,cpp}]
    (https://github.com/PokemonAutomation/Arduino-Source; R21: same run of
    blinks, same rounding, same search window). The C++ updates the clock in
    place and returns [false]; this port returns the new clock or why not, and
    the drift it logs as numbers. *)

type reanchored = {
  clock : Advance_clock.t;  (** Anchored on the newest blink. *)
  drift_seconds : float;
      (** How late the newest blink was against the old clock's prediction. *)
  drift_advances : float;  (** The same in advances. *)
}

type failure =
  | Too_few_blinks
      (** No such watcher, a run shorter than two, or fewer blinks than the run;
          the C++ returns [false] without logging. *)
  | Shared_tick  (** Two blinks a tick apart rounded to none: bad grouping. *)
  | Not_reidentified of string
      (** {!State_reidentifier} found no single fit; its reason. *)

val reanchor_absolute :
  Blink_recovery.config ->
  Blink_recovery.recovery ->
  Blink_extraction.blink_event list list ->
  origin:float ->
  Advance_clock.t ->
  (reanchored, failure) result
(** Takes the newest [reanchor_blinks] blinks of the recovery's anchor watcher
    from the streams (seconds from [origin]) and searches
    [reanchor_search_radius] advances either side of the clock's estimate for
    the first of them. Uses the recovery's state and anchor watcher, not its
    clock. *)
