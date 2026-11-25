(** How a log or a plan's text prints the engine's story actions
    ({!Engine_rules.Story_action}): [talk], [answer yes], [answer no], [scene],
    [save]. *)

val action : Engine_rules.Story_action.t -> string
(** The action, its name first. *)
