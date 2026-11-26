(** A program's run options: the [KEY=VALUE] choices [gamepilot run] takes in
    [--options] (one pair each, repeatable), as the program's registry entry
    declares them. A run's options are checked against the declaration before
    anything is pressed, recorded in its run.json and shown on its watch page,
    and its game's actions look them up ({!find}, {!int}).

    Game-agnostic: the keys and their values are the program's. *)

(** What a key's value may be. *)
type value =
  | One_of of string list  (** One of these words, as written. *)
  | Int_range of int * int
      (** A whole number from the first to the second, both included. *)
  | Text  (** Any text but the empty one. *)

(** When the key is not given. *)
type presence =
  | Required  (** The run is refused. *)
  | Optional  (** The run has no value for it. *)
  | Default of string  (** The run takes this value. *)

type decl = {
  key : string;  (** ["item"]: lower case, digits and [-] or [_]. *)
  value : value;
  presence : presence;
  doc : string;  (** One line: what the choice does. *)
}
(** One key a program takes. *)

type t
(** A run's options: each declared key given, or defaulted, with its value. *)

val none : t
(** No option: a program that declares none. *)

val pair : string -> (string * string, string) result
(** One [--options] argument, [KEY=VALUE] (the value keeps any later [=]);
    [Error] on a missing [=] or an empty key. *)

val check_decls : decl list -> (unit, string) result
(** A declaration's own errors: a key twice or not in the key alphabet, an empty
    [One_of] or [Int_range], a default its value refuses. *)

val check : decl list -> (string * string) list -> (t, string) result
(** The pairs given, read against the declaration: [Error] on a key given twice,
    a key it does not declare (naming the keys it takes and their values, or
    saying it takes none), a value its key refuses (naming what it takes), or a
    required key not given. *)

val pairs : t -> (string * string) list
(** The run's options in the declaration's order, defaults included: what
    run.json and the watch page show. *)

val find : t -> string -> string option
(** The key's value; [None] for an optional key not given (or one not declared).
*)

val int : t -> string -> int option
(** An [Int_range] key's value as a number. *)

val value_text : value -> string
(** ["master-ball | luxury-ball"], ["1 to 999"], ["text"]. *)

val describe : decl -> string
(** One line: ["item=master-ball | luxury-ball (required): the item to make"].
*)

val to_text : t -> string
(** ["item=master-ball withdraw=50"]; [""] for none. *)
