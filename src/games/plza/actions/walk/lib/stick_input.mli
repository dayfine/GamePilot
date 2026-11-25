(** PLZA's inputs as the wire sends them: a button press, a wait, and the left
    stick tilted toward an angle, walking or running. Ported from
    [PlzaConsoleBackend::press], [stick] and [wait]
    ([PokemonLZA_AutoStoryConsoleBackend.cpp]): fork #754 ([plza/mvp-0101])
    walks every stick; fork #644 ([plza/lean]) runs one asked to run (B held
    with the stick, for its time over {!run_speedup}) unless the run walks only,
    as every checkpoint before 03.03 does (dash is not unlocked yet, the C++'s
    [walk_before]). 01.01 walks only, so the two agree on it.

    Where we differ: #644 also looks 80 ms before a queued run ends, to queue
    the next slice back to back ([m_run_end]). The wire's submit returns once
    its batch is done, so each run here ends before the next look. *)

(** How fast a held direction moves the player ([Pokemon::StoryPace]). *)
type pace = Walk | Run

val run_speedup : float
(** 1.65: running covers this many times walking's distance in the same time
    (console B, 2026-11-19: 16.6 px/s walking, 27.0 px/s running on the full
    map), so a run is held for its walk time over this. *)

val position : float -> (Wire.stick, string) result
(** The stick toward [degrees] clockwise from straight on: [(sin, cos)], +x
    right and +y up. *)

val stick :
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
