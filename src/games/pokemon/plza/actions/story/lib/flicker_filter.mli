(** A reading that flickers, as the fork filters one
    (Pokemon/AutoStory/Engine/Pokemon_ScreenTimers.h): on once seen on [hits]
    reads within [window_ms], then on until unseen for [off_after_ms]. A story
    scene reads the battle HUD through one ({!Scene_machine}). *)

type t
(** The reads that saw it, and whether it is on. *)

val make : hits:int -> window_ms:float -> off_after_ms:float -> t
(** A filter, off, with no reads yet. *)

val battle_hud : unit -> t
(** The battle HUD's, as PokemonLZA_AutoStorySceneMachine.cpp filters it: on
    with two reads within 2 s, off after 3 s unseen. *)

val on_with : t -> bool -> float -> bool
(** [on_with t seen at_ms]: whether it is on with a read at [at_ms] that saw it
    or not; [t] unchanged. *)

val record : t -> bool -> float -> unit
(** [record t seen at_ms]: adds the read. *)
