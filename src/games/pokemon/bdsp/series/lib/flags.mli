(** Command-line flags for BDSP checkpoint series runs ({!Run_flags}). BDSP runs
    whole checkpoints on the Switch in testing mode only. *)

type t = unit Run_flags.flags
(** Parsed run flags with no BDSP-specific extra flags. *)

val parse : string list -> (t, string) result
(** Parses [gamepilot run] arguments for a BDSP series. *)

val takes : t -> (unit, string) result
(** Validates that no unsupported flags (such as non-testing [--mode],
    [--preflight], [--from-event], [--to-event], or [--max-rounds]) were given.
*)
