(** The four waits of an RNG attempt, from the target's advances and the
    calibrations: the title screen's (which picks the seed), the continue
    screen's, Teachy TV's and the in-game one (which reaches the advance).

    Port of [prepare_timings] (the fork's
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_RngCalibration.cpp]), the
    Sweet Scent row of [get_ingame_sequence] and [check_timings]
    ([PokemonFRLG_BlindNavigation.cpp]), and the frame constants of
    [PokemonFRLG_RngCalibration.h]. The C++ logs and throws; this returns the
    timings or the C++'s message.

    Where it differs: the C++ has one frame model, the Switch's (59.999977
    frames a second, two advances per in-game frame, a seed 845 ms after the
    table's delay). {!frame_model} makes it a value, with {!switch} the C++'s
    and {!mgba} measured on mGBA FireRed 1.1 after [backend.reset]: one advance
    per frame, the seed set by the press on the delay's own frame (the mGBA seed
    table holds press times), Sweet Scent's encounter 183 advances before the
    C++'s formula lands without the offset. *)

type frame_model = {
  frame_duration_ms : float;  (** [FRLG_FRAME_DURATION] *)
  ingame_advances_per_frame : float;
      (** the C++ divides the in-game advances by 2 *)
  fixed_seed_offset_ms : int;  (** [FIXED_SEED_OFFSET]: -845 *)
  sweet_scent_advances_offset : int;  (** [SWEET_SCENT_ADVANCES_OFFSET]: -352 *)
}

val switch : frame_model
(** The C++'s. *)

val mgba : frame_model
(** mGBA: 59.7275 frames a second, one advance per frame, no seed offset, Sweet
    Scent's offset -183. *)

val continue_screen_frames : int
(** [CONTINUE_SCREEN_FRAMES]: 200, the advances the continue screen is held for.
*)

val sweet_scent_fixed_duration_ms : int
(** [SWEET_SCENT_FIXED_DURATION]: 7400, the Sweet Scent presses' own share of
    the in-game wait. *)

type calibrations = {
  seed_offset : int;  (** frames *)
  csf_offset : int;  (** frames *)
  ingame_offset : int;  (** advances *)
}
(** [RngCalibrations]. *)

val no_calibrations : calibrations

type t = {
  seed_delay_ms : int;
  csf_delay_ms : int;
  teachy_delay_ms : int;
  ingame_delay_ms : int;
}
(** [RngTimings]. *)

val sweet_scent :
  frame_model ->
  seed_delay_ms:int ->
  advances:int ->
  use_teachy_tv:bool ->
  calibrations ->
  (t, string) result
(** [prepare_timings] for the Sweet Scent target: [seed_delay_ms] is the seed
    table's delay, [advances] the target's (the continue screen's 200 included).
    Error when a wait comes out negative or under [check_timings]'s minimums. *)
