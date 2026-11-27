(** Generated guide tables and example Switch command for BDSP programs. *)

val rows : plan_dir:string -> string list -> (string list, string) result
(** Formats one Markdown table row per checkpoint id in [ids], decoded from
    [plan_dir]. *)

val commands : args:string -> string
(** Formats the example Switch [gamepilot run] command for a BDSP program. *)
