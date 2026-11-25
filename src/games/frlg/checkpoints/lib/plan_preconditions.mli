(** A plan's declared preconditions: facts of the save its goal implies that no
    event's args say, from [metadata.preconditions] (Programs-As-Goals, section
    2). The pre-flight checks them with the needs {!Plan_needs} derives, and
    refuses the run before its first event when one fails. GamePilot's own.

    {v
"preconditions": {"badges": 8, "hall_of_fame": true}
"preconditions": {"badges": ["boulder", "cascade", "thunder"]}
    v}

    [badges] is a count (at least that many, 0 to 8) or the badges by name
    ({!Frlg_readers.Trainer_card_front.badge_names}); [hall_of_fame] takes
    [true] (the Hall of Fame entered). Both are read off the Trainer Card. *)

val needs : Checkpoints_plan.Plan.t -> (Plan_needs.need list, string) result
(** The plan's declared preconditions as needs: [[]] when it declares none.
    [Error] naming the field for a field not known, a count out of range, a
    badge not known, or a value of the wrong type. *)
