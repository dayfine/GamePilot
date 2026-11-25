(** Reads the party a checkpoint's postconditions promise
    ({!Postconditions.party}) from [metadata.postconditions]: [party] (every
    member, in order), or [party_includes] (the members the plans use) with
    [party_slots] (the positions they depend on,
    [[{"slot": 1, "species": "mr-mime"}]]). *)

val party : where:string -> Json_field.obj -> Postconditions.party option
(** [None] when none of the three is given. Raises {!Json_field.Invalid} for
    [party] with [party_includes] or with [party_slots], a slot outside 1-6, or
    an unknown field in a slot. *)
