(** Reads a plan's [metadata.postconditions] (or a repeat's [until]) into
    {!Postconditions.t}, as strictly as the engine's [Plan_decode] reads the
    rest: unknown fields and malformed values raise {!Json_field.Invalid} naming
    the field. *)

open Pokemon_rules

val mark_names : string list
(** The marks a party slot may promise: ["held_item"], ["mail"], ["none"]. *)

val postconditions : where:string -> Json_field.obj -> Postconditions.t
(** A postconditions object ([where] its prefix, as
    ["f: checkpoint.metadata.postconditions."]): also a repeat's [until]. *)
