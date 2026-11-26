(** The share of a box's pixels within a colour range, from its
    [core.color_count@1] probe ({!Wire.color_count_probe}), as every reader
    reads it. *)

val read : Effects.measurements -> string -> float option
(** The probe [id]'s share, 0 to 1; [None] when it is missing or of another
    kind. *)
