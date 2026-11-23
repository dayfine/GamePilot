(** Running from a wild battle that interrupts a walk: RUN on the action menu
    once it shows, then the talk settle back to the overworld ("Got away
    safely!"). A trainer's battle can't be run from; its settle then fails. *)

val menu_timeout_ms : int
(** The action menu showing after the battle's opening text: 20 s, B pressed
    through the text meanwhile. *)

val flee : log:(string -> unit) -> unit -> unit
(** Raises [Failure] when the menu never shows or the overworld never comes
    back: the walk can't go on. *)
