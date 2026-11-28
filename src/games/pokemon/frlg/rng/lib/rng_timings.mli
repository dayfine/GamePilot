(** The four waits of an RNG attempt, from the target's advances and the
    calibrations: the title screen's (which picks the seed), the continue
    screen's, Teachy TV's and the in-game one (which reaches the advance).

    Port of the timing preparation in
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_RngCalibration.cpp], its
    Sweet Scent in-game sequence and timing checks in
    [PokemonFRLG_BlindNavigation.cpp], and the frame constants of
    [PokemonFRLG_RngCalibration.h]
    (https://github.com/PokemonAutomation/Arduino-Source). The C++ logs and
    throws; this returns the timings or the C++'s message.

    Where it differs: the C++ has one frame model, the Switch's (59.999977
    frames a second, two advances per in-game frame, a seed 845 ms after the
    table's delay). {!frame_model} makes it a value, with {!switch} the C++'s
    and {!mgba} measured on mGBA FireRed 1.1 after [backend.reset]: one advance
    per frame, the seed set by the press on the delay's own frame (the mGBA seed
    table holds press times), Sweet Scent's encounter 183 advances before the
    C++'s formula lands without the offset. *)

type frame_model = {
  frame_duration_ms : float;
      (** One game frame, in ms: 1000/59.999977 on the Switch. *)
  ingame_advances_per_frame : float;
      (** RNG advances per frame in the overworld: 2 on the Switch, as the C++
          divides the in-game advances by 2. *)
  fixed_seed_offset_ms : int;
      (** Added to the title screen's wait: the seed is set this long after the
          seed table's delay (-845 on the Switch). *)
  sweet_scent_advances_offset : int;
      (** Advances Sweet Scent's encounter lands before the target's formula
          says (-352 on the Switch). *)
  static_advances_offset : int;
      (** Advances a static overworld encounter lands relative to the target's
          formula (160 on the Switch, 0 on mGBA). *)
}
(** How a machine runs the game: how long a frame lasts and how the RNG advances
    with it. *)

val switch : frame_model
(** The C++'s. *)

val mgba : frame_model
(** mGBA: 59.7275 frames a second, one advance per frame, no seed offset, Sweet
    Scent's offset -183, static encounter offset 0. *)

val continue_screen_frames : int
(** 200: the advances the continue screen is held for. *)

val sweet_scent_fixed_duration_ms : int
(** 7400: the Sweet Scent presses' own share of the in-game wait, in ms. *)

val gift_fixed_duration_ms : int
(** 5000: the Game Corner prize-claim presses' own share of the in-game wait, in
    ms. *)

val static_fixed_duration_ms : int
(** 5000: the static encounter's own share of the in-game wait, in ms (4000 ms
    save load + recap and 1000 ms opening and closing the Start menu). *)

type calibrations = {
  seed_offset : int;
      (** Frames added to the title screen's wait, to hit the target seed. *)
  csf_offset : int;
      (** Frames added to the continue screen's wait (csf: continue screen
          frames). *)
  ingame_offset : int;
      (** Advances added to the in-game wait, to hit the target advance. *)
}
(** One console's corrections to the computed waits, found by calibrating it
    against the seeds and advances it actually hits. *)

val no_calibrations : calibrations
(** Every offset 0: an uncalibrated console. *)

type t = {
  seed_delay_ms : int;
      (** How long the title screen is held before the press that sets the seed.
      *)
  csf_delay_ms : int;
      (** How long the continue screen is held before loading the save. *)
  teachy_delay_ms : int;
      (** How long Teachy TV plays, advancing the RNG fast; 0 without it. *)
  ingame_delay_ms : int;
      (** How long to wait in the overworld before Sweet Scent, so its encounter
          lands on the target advance. *)
}
(** The four waits of one attempt, in ms. *)

val sweet_scent :
  frame_model ->
  seed_delay_ms:int ->
  advances:int ->
  use_teachy_tv:bool ->
  calibrations ->
  (t, string) result
(** The waits for a Sweet Scent target: [seed_delay_ms] is the seed table's
    delay, [advances] the target's (the continue screen's 200 included). Error
    when a wait comes out negative or under the C++'s minimums (continue screen
    3200 ms, title screen 29650 ms, room for the Sweet Scent presses). *)

val gift :
  frame_model ->
  seed_delay_ms:int ->
  advances:int ->
  use_teachy_tv:bool ->
  calibrations ->
  (t, string) result
(** The waits for a Method 1 gift target (such as a Celadon Game Corner prize):
    same title-screen and continue-screen timing as {!sweet_scent}, without the
    Sweet Scent advance offset and checked against {!gift_fixed_duration_ms}. *)

val static :
  frame_model ->
  seed_delay_ms:int ->
  advances:int ->
  use_teachy_tv:bool ->
  calibrations ->
  (t, string) result
(** The waits for a Method 1 static overworld encounter (such as Zapdos,
    Articuno, Moltres, or Electrode): same title-screen and continue-screen
    timing as {!sweet_scent}, using [static_advances_offset] and checked against
    {!static_fixed_duration_ms} with zero extra minimum wait, matching
    [PokemonFRLG_BlindNavigation.cpp]. *)
