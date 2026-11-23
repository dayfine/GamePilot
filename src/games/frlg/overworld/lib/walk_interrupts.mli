(** What stops the player part-way through a leg on FireRed, as the walker's
    {!Grid_walker.Leg_interrupt.t}s. Ported from the fork's
    Overworld/PokemonFRLG_OverworldWalk ([LateWildBattleInterrupt],
    [MessageInterrupt]) and PokemonFRLG_OverworldWalkWatches.

    The fork also sees a wild battle by its first flashes; there is no flash
    reader here yet, so a battle is seen by its screen
    ({!Frlg_readers.Battle_screen}), which places an open leg's stop only
    roughly. *)

exception Trainer_battle
(** A battle started after a message: a trainer saw the player. It can't be
    fled, so the walk stops for the caller. *)

exception Message_stuck
(** A message on the overworld did not close after its presses. *)

val late_wild_battle_delay_ms : int
(** 3700: from the step that set a wild battle off to its screen (console B,
    2026-11-01, Route 1). *)

val trainer_battle_watch_ms : int
(** 6000: after a message closes, how long a trainer's battle may take to show.
*)

val wild_battle : flee:(unit -> unit) -> Grid_walker.Leg_interrupt.t
(** A wild battle's screen, cleared by [flee] (which leaves the player on the
    overworld). *)

val message : unit -> Grid_walker.Leg_interrupt.t
(** The white text box (a sign, someone speaking, a trainer who saw the player):
    B until it closes, then a watch for a trainer's battle. Raises
    {!Message_stuck} or {!Trainer_battle}. *)

val for_leg :
  flee:(unit -> unit) -> wild:bool -> Grid_walker.Leg_interrupt.t list
(** A battle first, then a message, on a leg where a wild battle can start; else
    only a message. *)
