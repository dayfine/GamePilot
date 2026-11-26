(** Iterative one-shot PoC program [bdsp.underground_poc] for bringing up BDSP
    Grand Underground automation on the Switch with [gamepilot run --watch].

    Iteration 1: verify overworld control on the Switch by clearing any dialog,
    opening the X menu ({!Bdsp_readers.Menu_detector}), and closing it cleanly. *)

val default_state : string
(** Unused on Switch ([--console]); kept for the one-shot runner interface. *)

val run : ?state:string -> unit -> bool * string
(** Run the PoC in the active effect session. Returns [(passed, summary_line)]. *)
