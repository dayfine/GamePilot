(** Runs a test's table of cases and reports each: a case passes when its input
    gives its expectation. Shared by the tests of every layer. *)

type case = {
  name : string;
  input : unit -> string;  (** What the code under test gives, as text. *)
  expectation : string;
}
(** A case whose result is text. *)

val run : string -> case list -> unit
(** Runs the cases of the named suite, prints each result, and exits with 1 if
    any case's text is not its expectation. *)

val report : string -> (unit, string) result -> unit
(** Prints a case checked by hand: [Ok] passes, [Error why] fails. *)

val finish : unit -> unit
(** Exits with 1 if any {!report}ed case failed. *)
