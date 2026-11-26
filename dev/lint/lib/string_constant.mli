(** The text of a string constant in the parse tree, on OCaml 5.2 and 5.3: 5.3
    wraps [Parsetree.constant] in a record ([pconst_desc]), 5.2 does not. dune
    copies [string_constant_5_2.ml.in] or [string_constant_5_3.ml.in] here by
    the compiler's version. *)

val text : Parsetree.constant -> string option
(** [Some s] for a string constant; [None] for any other constant. *)
