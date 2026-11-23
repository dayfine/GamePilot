(** Running from a wild battle that interrupts a walk: {!Frlg_battle.Wild_flee}
    on the screen ({!Frlg_battle.Screen_driver}), then the talk settle until the
    overworld is quiet and in control. The battle's probes
    ({!Frlg_battle.Battle_look.probes}) are subscribed for the flee only. *)

val flee : log:(string -> unit) -> unit -> unit
(** Raises [Failure] when the battle is not fled (a trainer's battle, no escape,
    a screen the flee has no answer for) or the overworld never comes back: the
    walk can't go on. *)
