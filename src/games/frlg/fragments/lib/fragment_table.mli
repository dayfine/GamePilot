(** The fragments table (src/games/frlg/fragments/fragments.json): named,
    parameterized runs of events a plan calls instead of writing them out
    (Programs-As-Goals section 3). A fragment has no save of its own: if it
    fails halfway, the checkpoint around it runs again.

    Each fragment lists its [params] and its [events], written as a plan's
    events. In every string of them, [{name}] stands for the argument of
    parameter [name]; an event's [id] is a suffix of the call's id ([""] for the
    call's id itself, ["walk"] for [CALL.walk]). *)

type fragment = {
  name : string;
  params : string list;
  events : (string * Yojson.Safe.t) list list;  (** As written, unsubstituted. *)
}

type t

val format : string
(** ["gamepilot-fragments/1"]. *)

val asset : string
(** The table's path from the repo root. *)

val parse : source:string -> Yojson.Safe.t -> (t, string) result
(** The table in the JSON. An error names [source] and the fragment: a field
    missing or of the wrong type, an event without a string [id], or a [{name}]
    that is not one of its params. *)

val load : unit -> (t, string) result
(** The table in {!asset}, read once. *)

val fragments : t -> fragment list
(** In the file's order. *)

val find : t -> string -> (fragment, string) result
(** The fragment of that name; an unknown name's error suggests the nearest. *)

val substitute : (string * string) list -> Yojson.Safe.t -> Yojson.Safe.t
(** The JSON with each [{name}] in its strings replaced by [name]'s value. *)
