(** One-shot program [bdsp.underground] for BDSP Grand Underground Mysterious
    Shard farming on the Switch with [gamepilot run --watch].

    Uses {!Bdsp_readers.Underground_screen} for unified frame classification,
    3-zone minimap sparkle steering around the central Hideaway ring, live
    Hammer/Pickaxe tool-panel verification, and
    {!Bdsp_underground.Mining_counters}. Supports
    [--options mode=farm|check-bag], [--options cycles=N], and
    [--options slates=N]. *)

val default_state : string
(** Unused on Switch ([--console]); kept for the one-shot runner interface. *)

val run : ?options:Run_options.t -> ?state:string -> unit -> bool * string
(** Run the program in the active effect session with the checked [options].
    Returns [(passed, summary_line)]. *)
