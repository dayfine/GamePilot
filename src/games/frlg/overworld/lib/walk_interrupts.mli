(** What stops the player part-way through a leg on FireRed, as the walker's
    {!Grid_walker.Leg_interrupt.t}s. Ported from the fork's
    Overworld/PokemonFRLG_OverworldWalk ([LateWildBattleInterrupt],
    [WildBattleInterrupt], [LateWildBattleInterrupt], [MessageInterrupt]) and
    PokemonFRLG_OverworldWalkWatches.

    A wild battle is seen by its first flashes ({!Battle_flash}), which place
    the step that set it off within half a tile; if they are missed, by its
    screen ({!Frlg_readers.Battle_screen}) seconds later, which places it only
    roughly. *)

val probes : Wire.probe_spec list
(** What the interrupts read: the fade (the flash), the dialog box and the
    battle's start ({!Frlg_readers.Screen_facts.probes}). The battle itself
    subscribes its own in the flee. *)

exception Trainer_battle
(** A battle started after a message: a trainer saw the player. It can't be
    fled, so the walk stops for the caller. *)

exception Message_stuck
(** A message on the overworld did not close after its presses. *)

val late_wild_battle_delay_ms : int
(** 3700: from the step that set a wild battle off to its screen (console B,
    2026-11-01, Route 1). *)

val wild_flash_delay_ms : int
(** 250: from the step that set a wild battle off to {!Battle_flash} firing. *)

val flash_watch_ms : int
(** 600: how long a hold on a leg with wild battles is watched after its
    release, so a battle set off by its last steps is seen by its flashes and
    timed from the hold's start like one during it. *)

val trainer_battle_watch_ms : int
(** 6000: after a message closes, how long a trainer's battle may take to show.
*)

val wild_flash : flee:(unit -> unit) -> Grid_walker.Leg_interrupt.t
(** A wild battle's first flashes, cleared by [flee] (which leaves the player on
    the overworld). Each call watches with a fresh {!Battle_flash.t}. *)

val wild_battle : flee:(unit -> unit) -> Grid_walker.Leg_interrupt.t
(** A wild battle's screen, when its flashes were missed; cleared by [flee]. *)

val message : unit -> Grid_walker.Leg_interrupt.t
(** The white text box (a sign, someone speaking, a trainer who saw the player):
    B until it closes, then a watch for a trainer's battle. Raises
    {!Message_stuck} or {!Trainer_battle}. *)

val for_leg :
  flee:(unit -> unit) -> wild:bool -> Grid_walker.Leg_interrupt.t list
(** A battle's flashes, its screen, then a message, on a leg where a wild battle
    can start; else only a message. *)
