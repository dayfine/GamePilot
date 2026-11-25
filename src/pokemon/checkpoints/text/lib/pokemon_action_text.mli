(** The Pokémon actions ({!Pokemon_rules.Pokemon_action}) as text. *)

open Pokemon_rules

val text : Pokemon_action.t -> string
(** The kind with its typed args, its name first:
    ["route to Town (4, 0) north"], ["battle (may lose)"],
    ["shop 2 retro-mail"]. *)
