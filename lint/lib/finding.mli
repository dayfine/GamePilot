(** One problem a check found at a place in the tree. *)

type severity =
  | Error  (** Fails the run. *)
  | Advisory  (** Printed, never fails the run. *)

type t = {
  check : string;  (** Check name, as used in the exceptions file. *)
  path : string;  (** File (or dune file) the finding is about. *)
  line : int;  (** 1-based; 0 when the finding is about the whole file. *)
  message : string;
  severity : severity;
}

val error : check:string -> path:string -> line:int -> string -> t
val advisory : check:string -> path:string -> line:int -> string -> t

val to_string : t -> string
(** [path:line: [check] message], with [advisory] in front of advisory ones. *)
