(** Runs a checkpoint's events in order through a game's handlers ({!Game.t}).

    Before any event runs, every game action the checkpoint names must have a
    handler. Then, per event: it is skipped when a flag its [skip_if] names
    holds; otherwise its handler runs, and once it passes, the game's position
    (when it can tell) must match a grid [declared_after]. The first event that
    fails stops the run. Each event's start (with its [why]), skip, end and
    failure is logged as ["[Story] <checkpoint> #<n> <event>: ..."]. A handler
    that raises is logged as failed and the exception passes through.

    An event's [once_per_save] is the game's to honour in its handler: only the
    game knows what its save already holds. The runner neither saves nor
    reloads: the caller (or {!Repeat_until}) decides that. *)

val run : Game.t -> Plan.checkpoint -> (unit, Failure.t) result
