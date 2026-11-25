(** An implementation file parsed with the compiler's own parser, and the
    function bindings in it. *)

type t = {
  path : string;
  text : string;
  lines : string array;
  structure : Parsetree.structure;
}

type function_binding = {
  name : string;
  start_line : int;
  end_line : int;
  body : Parsetree.expression;
}

val parse : path:string -> string -> (t, Finding.t) result
(** A file that does not parse is a finding ([parse]), never a silent pass. *)

val function_bindings : t -> function_binding list
(** Every [let] whose right-hand side is a function, at top level and inside
    submodules, in source order. Local [let ... in] functions belong to their
    enclosing binding. *)

val source_text : t -> Location.t -> string
(** The text a location spans. *)
