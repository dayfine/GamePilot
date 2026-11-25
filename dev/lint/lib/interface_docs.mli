(** Every item of a library interface has a doc comment (review rule R11,
    [.agents/rules/review-rules.md]). In an [.mli], each [val] (and [external]),
    each [type], each variant constructor, each constructor added to an
    extensible type and each [exception] needs one, including those inside
    module signatures. A doc comment counts when the compiler attaches it to the
    item: right before it or right after it, with no blank line between. A
    constructor is also covered when its type's doc names it as a word, and a
    re-exported variant ([type t = M.t = A | B]) leaves its constructors to [M],
    where they are defined. A type whose fields carry docs but which has none
    itself is a finding of its own: the fields say what each part holds, not
    what the whole is. Tags of polymorphic variants are not checked. *)

val check : path:string -> string -> Finding.t list
(** [check ~path text] over an interface's text: one finding per undocumented
    item, at its line. An interface that does not parse is a [parse] finding. *)
