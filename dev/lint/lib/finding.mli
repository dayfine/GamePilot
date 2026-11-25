(** One problem a check found at a place in the tree. *)

(** Whether a finding fails the run. *)
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
(** A finding: which check, where, and what it says. *)

val error : check:string -> path:string -> line:int -> string -> t
(** [error ~check ~path ~line message]: a finding that fails the run. *)

val advisory : check:string -> path:string -> line:int -> string -> t
(** [advisory ~check ~path ~line message]: a finding that is only printed. *)

val to_string : t -> string
(** [path:line: [check] message], with [advisory] in front of advisory ones. *)
