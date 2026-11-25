(** A command's step, by name: what the pre-flight and make-room commands show
    on the watch page as a generated plan ([soft_reset], [read_party], ...). The
    step takes no args; it runs through the step table the command hands the
    checkpoint run ([docs/design/Composable-Rules.md]). Its plan format is
    [Engine_plan_format.Command_step_decode]. *)

type t = string
(** The step's name, as the command's step table names it. *)

val to_string : t -> string
(** The step as a log prints it, its name: ["soft_reset"]. *)
