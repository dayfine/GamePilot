(** The library graph parts of a dune file: which libraries a directory defines
    and which libraries each stanza links. *)

type stanza = {
  line : int;
  defines : string list;  (** [name] and [public_name] of a library. *)
  libraries : string list;
      (** The [libraries] field; [re_export] forms are unwrapped, [select] forms
          are skipped. *)
}
(** One stanza of a dune file, by the line it starts on. *)

val parse : string -> (stanza list, string) result
(** Stanzas with a [libraries] field or that define a library. *)
