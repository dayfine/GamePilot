(** Making a folder as a [Result]: [Unix.mkdir], which fails with [EEXIST] when
    the name is taken, so two processes that race for one name never both get
    it. The one place the run record catches [Unix_error]. *)

type made = Made | Taken  (** Taken: something already has that name. *)

val make : string -> (made, string) result
(** The folder, made now unless the name is taken; [Error] for any other failure
    (no parent, no permission), naming the path. *)

val make_all : string -> (unit, string) result
(** The folder and its parents, any of them already there (a folder another
    process made meanwhile included); [Error] when one cannot be made or a name
    on the way is taken by a file. *)
