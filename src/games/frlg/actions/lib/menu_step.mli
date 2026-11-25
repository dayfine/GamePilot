(** A menu step from {!Menu_input} and the actions built on it, which fail by
    raising {!Menu_input.Action_failed}, as a Result: the one place the Rare
    Candy actions ({!Rare_candy_steps}, {!Candy_actions}) meet that exception.
    Main's [Action_failed] is to be converted to Result in its own PR, and this
    module then goes. *)

val result : (unit -> 'a) -> ('a, Checkpoints_run.Failure.cause) result
(** The step run through {!Menu_input.run} (its probes subscribed, only those
    not held already); [Error] with the cause it failed with. *)
