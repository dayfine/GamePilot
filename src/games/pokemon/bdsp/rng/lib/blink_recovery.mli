(** Recovers the RNG state from the NPCs' blinks as they arrive: estimate each
    watcher's blink threshold, turn the samples into blink streams, solve once
    enough rolls are in, hold the first state as provisional and confirm it with
    a later solve over more blinks, then anchor the advance clock on the newest
    blink. A pure step: each {!poll} takes the watchers' samples so far and says
    what the loop decided.

    Port of the decision logic of [recover_state_from_blinks] and
    [solve_blink_window] in
    [PokemonBDSP/Programs/RngManipulation/PokemonBDSP_BlinkRecovery.{h,cpp}]
    (https://github.com/PokemonAutomation/Arduino-Source; R21: same checks in
    the same order, same thresholds, same messages). Left to the caller, which
    owns the video and the clock: the poll wait, the keep-awake nudges, the
    progress display, the sample log and the watchers, so the window slide the
    C++ does on them ([discard_blinks_before]) comes back as
    {!outcome.discard_before}. {!Blink_reanchor} ports [reanchor_absolute];
    [hold_and_reanchor], the scene waits and the watcher setup are not ported.
    Times are seconds as a [float]; the C++'s per-watcher thresholds, frozen
    together on the first solve, become one option. *)

type config = {
  npcs : int;  (** NPCs sharing the RNG; one advance each per tick. *)
  min_rolls_to_try : int;
  confirmation_events : int;
      (** Rolls past the provisional state before it is checked, and failed
          solves in a row before it is dropped. *)
  window_events : int;  (** Rolls kept while searching, across all watchers. *)
  max_failed_windows : int;
      (** The attempt gives up after this many windows of failed solves. *)
  liveness_timeout_seconds : int;  (** Gives up when no blinks arrive at all. *)
  reanchor_blinks : int;  (** {!Blink_reanchor}'s run of newest blinks. *)
  reanchor_search_radius : int;
}
(** The decision fields of [BlinkRecoveryConfig]; its poll, keep-awake,
    retention and re-anchor timing fields belong to the caller. *)

val default_config : config
(** 2 NPCs, 44 rolls, 6 to confirm, a window of 52, 3 windows, an hour, 6 blinks
    to re-anchor within 600 advances. *)

type recovery = {
  state : Xorshift128.state;  (** Before the first watched roll. *)
  clock : Advance_clock.t;  (** Anchored on the newest blink. *)
  events : int;  (** Rolls the confirming solve used. *)
  thresholds : float list;  (** Per watcher, frozen at the first solve. *)
  slots : int list;  (** Each watcher's place in the NPCs' order. *)
  anchor_stream : int;  (** The watcher whose blink anchors the clock. *)
}
(** [BlinkRecovery] on success. *)

(** Each [continue] of the C++ loop. *)
type waiting =
  | No_samples  (** A watcher has no samples yet. *)
  | No_threshold  (** A watcher's blink threshold cannot be estimated yet. *)
  | Not_fresh  (** No watcher saw a new blink since the last pass. *)
  | Too_few_blinks  (** The busiest watcher has fewer than three. *)
  | No_tick_fit
  | Confirming  (** Too few rolls past the provisional state yet. *)
  | Too_few_rolls  (** Fewer than [min_rolls_to_try]. *)
  | Unsolved  (** The solve failed, and no held state was dropped. *)

type decision =
  | Keep_collecting of waiting
  | Provisional of { state : Xorshift128.state; events : int }
  | Changed of { state : Xorshift128.state; events : int }
      (** A different state replaced the provisional one. *)
  | Dropped
      (** The provisional state stopped solving: a blink was probably misread.
      *)
  | Confirmed of recovery
  | Gave_up of string  (** The C++'s [failure_reason]. *)

type outcome = {
  decision : decision;
  events : int option;  (** Rolls in the streams, once they were built. *)
  discard_before : float option;
      (** Every watcher drops its samples older than this before the next poll
          ([EyeBlinkWatcher::discard_before]): the window slides to the newest
          [window_events] blinks, after the solve and only while no state is
          held. *)
}

type t
(** The loop's state between polls. *)

val start : config -> watchers:int -> now:float -> t
(** Before the first poll; [now] starts the liveness timeout. *)

val poll :
  t -> now:float -> Blink_extraction.match_sample list list -> t * outcome
(** One pass of the loop over every watcher's samples so far (in watcher order,
    each oldest first). After [Confirmed] or [Gave_up] the attempt is over. *)
