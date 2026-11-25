(** The zone catches' aim under held ZL: read the plates by flicking right,
    choose the nearest not caught, and step toward it. Ported from
    PokemonLZA_AutoStoryCatches.cpp, with the decisions of {!Catch_plan}. *)

val lock_on_wait_ms : int
(** How long ZL is held for a first plate: 3 s (the lock shows over 1.5 s after
    ZL at times). *)

val log_target : Story_steps.game_steps -> string -> Catch_plan.target -> unit
(** "[PLZA] catch_in_zone: <what>: plate at (x, y), <caught text>". *)

type choice = {
  target : Catch_plan.target option;  (** none when none was chosen *)
  saw_plates : bool;
}

val approach :
  Story_steps.game_steps ->
  Held_zl.t ->
  Catch_plan.target ->
  misses:int ->
  Catch_plan.target
(** Forward 500 ms under ZL while {!Catch_plan.step_toward} says so, reading the
    plate after each step; the lock keeps the camera on the target. The last
    plate read (the one before, when it went). *)

val choose_and_approach : Story_steps.game_steps -> choice
(** ZL held from a fresh start: up to 4 plates read by flicking right, the
    nearest one not marked caught chosen, then {!approach} the choice. *)
