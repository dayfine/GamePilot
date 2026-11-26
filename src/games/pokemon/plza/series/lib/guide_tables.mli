(** What PLZA's story rules give a program's user guide (docs/guide/): each
    checkpoint's row and the commands that run them. PLZA runs through gamepilot
    checkpoints itself, from where the console is. *)

val rows : plan_dir:string -> string list -> (string list, string) result
(** Each checkpoint's table row: its id and its plan's title. *)

val commands : args:string -> string
(** The Switch command for [args] (--program, --from, --to). *)
