(** Waking a dimmed Switch screen with the right stick: up 100 ms, then down 100
    ms, then 500 ms for the dim to lift. Ours (the fork runs its programs with
    the console awake). Moved out of PLZA's story actions
    ({!Plza_story.Screen_wake}, which says why the right stick and why up then
    down) so any program on the Switch can wake the screen the same way. The
    Switch dims its screen after a while with no input, and a dimmed frame reads
    as nothing. *)

val commands : Wire.command list
(** The tilt up, the tilt down and the wait after it. *)

val run : unit -> unit
(** Submits {!commands}. *)
