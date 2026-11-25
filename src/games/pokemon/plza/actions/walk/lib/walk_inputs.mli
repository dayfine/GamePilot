(** PLZA's inputs as the wire sends them: a button press, a wait, and the left
    stick tilted toward an angle ({!Switch_home.Stick_tilt}), walking or
    running. Ported from [PokemonLZA_AutoStoryConsoleBackend.cpp]: fork #754
    ([plza/mvp-0101]) walks every tilt; fork #644 ([plza/lean]) runs one asked
    to run (B held with the stick, for its time over {!run_speedup}) unless the
    run walks only. #644 walks every checkpoint before 03.03
    ([PokemonLZA_AutoStory.cpp]), kept here, though dash unlocks at 03.01 (seen
    by the user): 03.01 and 03.02 could run. 01.01 walks only, so #754 and #644
    agree on it.

    Where we differ: #644 also reads the screen 80 ms before a queued run ends,
    to queue the next slice back to back. The wire's submit returns once its
    batch is done, so each run here ends before the next screen read. *)

(** How fast a held direction moves the player. *)
type pace = Walk | Run

val run_speedup : float
(** 1.65: running covers this many times walking's distance in the same time
    (console B, 2026-11-19: 16.6 px/s walking, 27.0 px/s running on the full
    map), so a run is held for its walk time over this. *)

val tilt :
  walk_only:bool ->
  pace ->
  degrees:float ->
  duration_ms:int ->
  release_ms:int ->
  (Wire.command, string) result
(** The stick held toward [degrees] for [duration_ms], then centred for
    [release_ms]. At {!Run}, unless [walk_only], B is held with it for
    [duration_ms /. run_speedup] (truncated). *)

val button : Wire.button -> hold_ms:int -> release_ms:int -> Wire.command
(** A button held for [hold_ms], then released for [release_ms]. *)

val wait : int -> Wire.command
(** Nothing pressed for that many ms. *)
