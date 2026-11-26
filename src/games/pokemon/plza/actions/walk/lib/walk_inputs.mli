(** PLZA's inputs as the wire sends them: a button press, a wait, and the left
    stick tilted toward an angle ({!Switch_home.Stick_tilt}), walking or
    running. Ported from PokemonLZA_AutoStoryConsoleBackend.cpp: a tilt asked to
    run is run (B held with the stick, for its walk time over 1.65, running's
    speedup) unless the run walks only. Every checkpoint before the fork's 03.03
    walks (PokemonLZA_AutoStory.cpp), kept here (before 15-rock-pile-scene),
    though dash unlocks at 12-down-to-the-lobby: it and 13-out-of-hotel-z could
    run.

    Where we differ: the fork also reads the screen 80 ms before a queued run
    ends, to queue the next slice back to back. The wire's submit returns once
    its batch is done, so each run here ends before the next screen read. *)

(** How fast a held direction moves the player. *)
type pace = Walk  (** The stick alone. *) | Run  (** The stick with B held. *)

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
