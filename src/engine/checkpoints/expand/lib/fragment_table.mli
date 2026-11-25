(** A table of fragments: named, parameterized runs of events a plan calls
    instead of writing them out (Programs-As-Goals section 3). A game keeps its
    table as data ([gamepilot-fragments/1]) and {!Fragment_calls} expands the
    calls. A fragment has no save of its own: if it fails halfway, the
    checkpoint around it runs again.

    Each fragment names its [params], each with a kind the game knows
    (["town"]), and lists its [events], written as a plan's events. In their
    strings, [{name}] stands for the argument of parameter [name], and
    [{name.field}] for a field of what it names, which the game looks up
    ([{town.nurse}]: the town's nurse place). An event's [id] is a suffix of the
    call's id: [""] for the call's id itself, ["walk"] for [CALL.walk]. *)

type param = { param : string; param_kind : string }
(** A parameter's name and the kind of key its argument is. *)

type fragment = {
  name : string;
  params : param list;
  events : Plan_json.fields list;  (** As written, placeholders unfilled. *)
}
(** One fragment of the table. *)

type t
(** The table: its fragments by name, in the file's order. *)

val format : string
(** ["gamepilot-fragments/1"]. *)

val parse : source:string -> Yojson.Safe.t -> (t, string) result
(** The table in the JSON. An error names [source] and the fragment: a field
    missing or of the wrong type, an event without a string [id], or a
    placeholder that names no parameter. *)

val fragments : t -> fragment list
(** In the file's order. *)

val find : t -> string -> (fragment, string) result
(** The fragment of that name; an unknown name's error suggests the nearest. *)

val placeholders : string -> (string * string option) list
(** The [{name}] and [{name.field}] placeholders in a string, in order. *)
