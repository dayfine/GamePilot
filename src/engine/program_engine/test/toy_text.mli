(** How the toy prints its rules ({!Toy_rules}): the engine's zone and story
    texts, the toy's sets by a match, and the position before the toy's
    promises. *)

include Engine_text.Rules_text.TEXT with module T = Toy_rules
