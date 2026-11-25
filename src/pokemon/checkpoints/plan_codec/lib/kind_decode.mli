(** Reads the Pokémon actions ({!Pokemon_rules.Pokemon_action}) from a plan,
    with the format's fallbacks filled in. *)

open Pokemon_rules

val decoder :
  string -> (where:string -> Json_field.obj -> Pokemon_action.t) option
(** The decoder of the kind of that name, given the event's [args] ([where]
    their prefix), or [None] when the name is not a Pokémon kind. It raises
    {!Json_field.Invalid} on an unknown arg, as on a malformed one. *)
