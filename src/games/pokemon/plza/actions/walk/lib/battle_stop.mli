(** A walk with a story battle ahead stops on the battle HUD. Ported from fork
    PR 725 as its plza/lean branch has it: PokemonLZA_AutoStoryWalks.cpp (two
    battle HUD reads in a row stop the sliced last leg) and
    PokemonLZA_AutoStorySceneMachine.cpp (its battle on screen failure, and the
    flicker-filtered check its walk action makes before and after a walk). *)

val battle_on_screen : Engine_run.Failure.cause
(** [battle_on_screen]: the run goes on at the story battle. *)

val streak : stop_on_battle:bool -> int -> Screen.t -> int
(** The battle HUD's reads in a row, this one counted; 0 without
    [stop_on_battle]. *)

val holds : int -> bool
(** Two reads in a row or more: the walk stops. *)

val stopped :
  (string -> unit) ->
  string ->
  held_ms:int ->
  (unit, Engine_run.Failure.cause) result
(** [stopped log walk ~held_ms]: logged
    ["[PLZA] <walk>: battle HUD showed after <held_ms> ms of the last leg:
     stopping walk."], then {!battle_on_screen}. *)

type game_steps = { read_screen : unit -> Screen.t; wait : int -> unit }
(** What the check reads and does in the game. *)

val showing : game_steps -> bool
(** The battle HUD on the first read and again within 2 s (it flickers), reads
    250 ms apart, 8 at most; not on the first read: [false] at once. *)
