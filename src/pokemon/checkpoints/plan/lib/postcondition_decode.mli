(** Reads a plan's [metadata.postconditions] into {!Plan.postconditions}, as
    strictly as {!Plan_decode} reads the rest: unknown fields and malformed
    values are errors naming the field. *)

val mark_names : string list
(** The marks a party slot may promise: ["held_item"], ["mail"], ["none"]. *)

val of_metadata : where:string -> Json_field.obj option -> Plan.postconditions
(** The postconditions in the plan's metadata ([where] its prefix, as
    ["f: checkpoint."]); all empty when there is no metadata or it states none.
*)

val postconditions : where:string -> Json_field.obj -> Plan.postconditions
(** A postconditions object ([where] its prefix): also a repeat's [until]. *)
