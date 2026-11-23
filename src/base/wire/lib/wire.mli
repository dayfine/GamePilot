(** Wire protocol v1 (contracts/v1): message types and their JSON codec.

    One JSON object per line. The golden files in [contracts/v1] are the spec;
    [test/test_wire.ml] decodes and re-encodes every one of them. *)

type json = Yojson.Safe.t

exception Decode_error of string
(** Raised by every [*_of_json] function on a message that does not match the
    protocol. The string names the offending field. *)

(** {1 Values} *)

type button = A | B | Select | Start | Right | Left | Up | Down | R | L

val string_of_button : button -> string
val button_of_string : string -> button option

type command =
  | Press of { buttons : button list; hold_ms : int; cooldown_ms : int }
  | Wait of { wait_ms : int }

type box = { x : float; y : float; w : float; h : float }
(** Normalized to the frame, 0..1. *)

type delivery = Every | Latest

type probe_spec = { id : string; kind : string; box : box; delivery : delivery }
(** [kind] is an open set, e.g. ["core.color_stats@1"]. *)

type rgb = { r : float; g : float; b : float }

type probe_result =
  | Color_stats of { mean : rgb; stddev : rgb }  (** [core.color_stats@1] *)
  | Other of json  (** a kind this side does not know yet, kept verbatim *)

type frame = { seq : int; t_ms : float; probes : (string * probe_result) list }
(** One [frame] notification. [probes] keeps the daemon's order. *)

type batch_done = { batch_id : string; seq : int; t_ms : float }

type backend = {
  kind : string;
  game_code : string;
  frame_rate : float;
  width : int;
  height : int;
}

type hello_result = {
  protocol : int;
  daemon : string;
  backend : backend;
  probe_kinds : string list;
}

type submit_result = { batch_id : string; start_seq : int }
type error = { code : int; message : string; data : json option }

(** {1 Messages} *)

type call =
  | Hello of { protocol : int; client : string }
  | Load_state of { path : string }
  | Subscribe of probe_spec list
  | Submit of { batch_id : string; commands : command list }
  | Cancel

type request = { id : int; call : call }

type response = { id : int; outcome : (json, error) result }
(** A response does not name its method; decode [Ok] with the [*_result]
    decoders below, chosen by the request it answers. *)

type notification = Frame of frame | Batch_done of batch_done

type message =
  | Request of request
  | Response of response
  | Notification of notification

val method_name : call -> string
val message_of_json : json -> message
val json_of_message : message -> json

val message_of_string : string -> message
(** Parses one line. Raises [Decode_error] on bad JSON too. *)

val string_of_message : message -> string
(** One line, no trailing newline. *)

(** {1 Results} *)

val hello_result_of_json : json -> hello_result
val json_of_hello_result : hello_result -> json

val load_state_result_of_json : json -> int
(** The [seq] after loading. *)

val json_of_load_state_result : int -> json
val subscribe_result_of_json : json -> string list
val json_of_subscribe_result : string list -> json
val submit_result_of_json : json -> submit_result
val json_of_submit_result : submit_result -> json

val cancel_result_of_json : json -> int
(** The [released_seq]. *)

val json_of_cancel_result : int -> json

(** {1 Wire log} *)

type direction = In  (** from the client *) | Out  (** to the client *)
type log_line = { dir : direction; t_ms : float; msg : message }

val log_line_of_json : json -> log_line
val json_of_log_line : log_line -> json
