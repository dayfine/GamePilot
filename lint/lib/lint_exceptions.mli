(** The exceptions file: one waived finding source per line,
    [CHECK PATH REASON...]. [PATH] is a file, or a directory covering every file
    below it. A line without a reason is an error, and an entry that waives
    nothing is a finding, so the file only lists live debt. *)

type entry = { check : string; path : string; reason : string; line : int }

val parse : string -> (entry list, string) result

val apply : file:string -> entry list -> Finding.t list -> Finding.t list
(** [apply ~file entries findings] drops waived findings and adds one for each
    entry that waived nothing ([file] names the exceptions file in them). *)
