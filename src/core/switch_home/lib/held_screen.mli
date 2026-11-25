(** A screen that must read the same for a while before it counts: the fork's
    DetectorToFinder hold (CommonTools/VisualDetector.h, a PRESENT finder), as a
    watcher over the frames. *)

val held :
  float ->
  (Effects.measurements -> 'a option) ->
  Effects.measurements ->
  'a option
(** [held hold_ms read] is a watcher: [Some v] once [read] has given [Some v] on
    every frame for [hold_ms]. It keeps state; make a new one per wait, as the
    fork makes a new watcher. *)

val wait_for :
  timeout_ms:int -> (Effects.measurements -> 'a option) -> 'a option
(** The first value the watcher gives within [timeout_ms], or [None]. *)
