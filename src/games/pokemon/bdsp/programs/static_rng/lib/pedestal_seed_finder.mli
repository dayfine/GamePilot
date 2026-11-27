(** Quiet-room [0PK] player-blink 128-bit seed finder for Ramanas Park
    pedestals.

    Wraps {!Bdsp_rng.Blink_recovery} with [npcs = 1] over live
    {!Bdsp_readers.Eye_blink_reader} [core.template_ncc@1] frames while keeping
    the daemon input lease alive. Used as Step 1 of Workflow A in
    {!Static_rng_workflow}, where the player stands frozen by a key-item dialog
    in front of an empty pedestal before inserting a slate. *)

type config = {
  picture : Wire.box;  (** Normalized game picture bounds on the Switch. *)
  target : Bdsp_readers.Eye_blink_reader.target;
      (** Player eye ROI and uploaded open-eye template. *)
  min_rolls_to_try : int;
      (** Minimum player blinks before first GF(2) solve attempt (default 38).
      *)
  timeout_seconds : float;
      (** Maximum seconds to collect blinks before giving up (default 600.0). *)
  lease_renew_seconds : float;
      (** Interval in seconds between daemon lease renewals (default 30.0). *)
}
(** Configuration for one pedestal seed-recovery run. *)

type outcome = {
  state : Bdsp_rng.Xorshift128.state;
      (** Confirmed 128-bit [Xorshift128] state before the first watched roll.
      *)
  events : int;  (** Number of player blinks in the confirming solve. *)
  anchor_time_ms : float;
      (** Daemon clock timestamp in ms of the newest blink anchoring the clock.
      *)
  anchor_advance : int;
      (** Advance index of the newest blink relative to [state]. *)
  tick_seconds : float;  (** Fitted player blink tick period in seconds. *)
  elapsed_seconds : float;  (** Wall-clock seconds taken to confirm. *)
}
(** Confirmed 128-bit seed returned by {!run}. *)

val default_config :
  picture:Wire.box -> target:Bdsp_readers.Eye_blink_reader.target -> config
(** Default quiet-room [npcs = 1] configuration ([min_rolls_to_try = 38],
    [timeout_seconds = 600.0], [lease_renew_seconds = 30.0]). *)

val run : config -> (outcome, string) result
(** Subscribes to [config.target], collects player eye-blink samples, and polls
    {!Bdsp_rng.Blink_recovery} until the 128-bit seed is [Confirmed] or the run
    gives up / times out. *)
