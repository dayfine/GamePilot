(** The JSON-RPC 2.0 envelope: calls by method, responses by id, and the [frame]
    and [batch_done] notifications. *)

type json = Yojson.Safe.t
type error = { code : int; message : string; data : json option }

type call =
  | Hello of { protocol : int; client : string }
  | Load_state of { path : string }
  | Upload_template of { png : string }
  | Subscribe of Probe.probe_spec list
  | Unsubscribe of string list
  | Submit of { batch_id : string; commands : Command.command list }
  | Cancel

type request = { id : int; call : call }
type response = { id : int; outcome : (json, error) result }

type notification =
  | Frame of { load : int; frame : Probe.frame }
  | Batch_done of Command.batch_done

type message =
  | Request of request
  | Response of response
  | Notification of notification

val method_name : call -> string
val message_of_json : json -> message
val json_of_message : message -> json
val message_of_string : string -> message
val string_of_message : message -> string
