(** The Pokémon event kinds ({!Pokemon_terms.Own_kind}) as text. *)

open Pokemon_terms

val text : Own_kind.t -> string
(** The kind with its typed args, its name first:
    ["route to Town (4, 0) north"], ["battle (may lose)"],
    ["shop 2 retro-mail"]. *)
