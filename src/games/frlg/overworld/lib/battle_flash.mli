(** A wild battle's first sign: the overworld flashes dark twice within half a
    second of the step that set the battle off, seconds before the battle's own
    wipe and screen. Ported from the fork's
    Inference/PokemonFRLG_BattleFlashWatcher: the middle of the screen (the fade
    probe, {!Frlg_readers.Screen_facts.fade_id}) darkens by a fifth or more, not
    below two fifths, and starts to come back. A warp's fade only darkens, to
    black, so it does not count.

    On mGBA (2026-11-23, run 4 of mg-04, Pokemon Tower 3F) the screen dipped
    from a channel sum of 598 to 335 starting 4 frames after the step that set
    the battle off, and this watcher fired 13 frames after that step. *)

type t
(** A watcher: the brightness of the last {!window_ms} of frames it saw. *)

val window_ms : float
(** 400 ms: a flash goes dark and comes back within this. *)

val create : unit -> t

val seen : t -> Effects.measurements -> bool
(** Feeds the watcher one frame: whether a flash shows by it. Frames go in
    order; one without the fade probe is skipped. A flash fires once: the
    watcher forgets the frames before it. *)
