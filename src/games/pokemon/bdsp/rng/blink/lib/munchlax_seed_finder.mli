(** Boot-time 128-bit [Xorshift128] seed recovery from Munchlax's intro blinks.

    Subscribes to {!Bdsp_readers.Eye_blink_reader.probes} with
    [delivery = Every], drains {!Effects.take_gaps} on every poll, and renews
    the input lease via {!Effects.renew_lease} every ~30 s without sending any
    controller input so long silent waits never drop the lease or trigger daemon
    keep-awake presses. Extracts blink timestamps via
    {!Bdsp_rng.Blink_extraction} and solves/confirms the 128-bit seed with
    {!Bdsp_rng.Pokemon_blink_solver}.

    Port of
    [SerialPrograms/Source/PokemonBDSP/Programs/RngManipulation/PokemonBDSP_IntroSeedFinder.cpp]
    (https://github.com/PokemonAutomation/Arduino-Source), adapted to the
    GamePilot effect set and lease-renewal keepalive
    (https://github.com/dayfine/Arduino-Source/pull/782). *)

type config = {
  picture : Wire.box;  (** Game picture viewport for probe clipping. *)
  target : Bdsp_readers.Eye_blink_reader.target;
      (** Eye-blink probe target (typically
          {!Bdsp_readers.Eye_blink_reader.munchlax_target}). *)
  tolerance_seconds : float;
      (** Timing tolerance passed to {!Bdsp_rng.Pokemon_blink_solver} (default
          0.10 s). *)
  max_blinks : int;
      (** Maximum blinks to collect before giving up (default 140). *)
  timeout_seconds : float;
      (** Maximum wall-clock wait before giving up (default 1500.0 s). *)
  lease_renew_seconds : float;
      (** Interval between silent {!Effects.renew_lease} calls (default 30.0 s).
      *)
  confirmation_blinks : int;
      (** Extra blinks required to confirm a provisional solve (default 6). *)
  max_attempts : int;
      (** Maximum subset leave-one-out attempts per solve (default 64). *)
}
(** Configuration for {!run}. *)

val default_config :
  picture:Wire.box -> template:Effects.template_hash -> config
(** Default Munchlax intro seed-finder configuration matching upstream
    [PokemonBDSP_IntroSeedFinder] tolerances with 30 s silent lease renewal. *)

type outcome = {
  state : Bdsp_rng.Xorshift128.state;
      (** Confirmed 128-bit state before the first solved interval's roll. *)
  solve : Bdsp_rng.Pokemon_blink_solver.result;
      (** Full solver diagnostics from the confirming solve. *)
  blink_count : int;  (** Total blinks extracted when confirmed. *)
  gaps : Bdsp_rng.Blink_extraction.frame_gap list;
      (** Capture gaps observed via {!Effects.take_gaps} (in seconds from the
          first sample). *)
  threshold : float;  (** Auto-estimated blink-depth threshold used to solve. *)
  elapsed_seconds : float;  (** Seconds elapsed from start to confirmation. *)
}
(** Confirmed boot seed and telemetry returned by {!run}. *)

val run : config -> (outcome, string) result
(** Watches Munchlax blink until a unique 128-bit {!Bdsp_rng.Xorshift128.state}
    is confirmed across {!config.confirmation_blinks} additional blinks, or
    returns [Error] on timeout, [max_blinks] exhaustion, or missing probe. *)
