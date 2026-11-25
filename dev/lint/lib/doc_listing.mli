(** A doc comment that lists what plugs in (review rule R1,
    [.agents/rules/review-rules.md]). An [.mli] doc comment that
    cross-references the same registration value in two or more other modules
    ([Mail_glitch_use.handlers] and [Candy_actions.handlers], each in [{!...}])
    is a list that grows with every addition; a doc says what the thing does.
    The values that count as registrations are the config's [doc_listing] names.
*)

val check : Config.t -> path:string -> string -> Finding.t list
(** [check config ~path text] over an [.mli]'s text: one finding per doc
    comment, at its first line. Other files and an empty [doc_listing] pass. *)
