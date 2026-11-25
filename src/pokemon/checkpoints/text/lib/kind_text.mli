(** The Pokémon event kinds ({!Pokemon_rules.Own_kind}) as text. *)

open Pokemon_rules

val text : Own_kind.t -> string
(** The kind with its typed args, its name first:
    ["route to Town (4, 0) north"], ["battle (may lose)"],
    ["shop 2 retro-mail"]. *)
