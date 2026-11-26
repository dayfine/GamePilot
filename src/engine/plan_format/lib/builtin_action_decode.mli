(** How a plan writes the engine's story actions
    ({!Engine_rules.Builtin_action}): [talk], [scene] and [save] with no args,
    [answer] with [yes] (a bool, default [true]). *)

include Action_parts.ACTION_DECODE with type t = Engine_rules.Builtin_action.t
