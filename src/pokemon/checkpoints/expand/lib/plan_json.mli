(** A checkpoint plan's raw JSON, as the load-time rewriters ({!Place_routes},
    and a game's own) read and rebuild it before the plan is decoded: field
    access that never raises, and each event rewritten into the events it stands
    for. *)

type fields = (string * Yojson.Safe.t) list
(** A JSON object's fields, in file order. *)

val fields_of : Yojson.Safe.t -> fields
(** The object's fields; [[]] for anything else (the decoder reports it). *)

val object_field : string -> fields -> fields
(** The fields of the object field; [[]] when missing or not an object. *)

val string_field : string -> fields -> string option
(** The string field; [None] when missing or not a string. *)

val set : string -> Yojson.Safe.t -> fields -> fields
(** The field replaced in place, or added at the end. *)

val without : string -> fields -> fields
(** The fields with that key removed. *)

val rewrite_events :
  source:string ->
  start:(fields -> 'state) ->
  step:('state -> fields -> (Yojson.Safe.t list * 'state, string) result) ->
  Yojson.Safe.t ->
  (Yojson.Safe.t, string) result
(** The plan with each of [checkpoint.events] replaced, in order, by the events
    [step] gives for it, threading a state that [start] makes from the
    [checkpoint] object. An error is prefixed with [source] and the event
    (["01-celadon-setup.plan.json: checkpoint.events[4]: ..."]). A plan with no
    event list comes back unchanged, for the decoder to report. *)
