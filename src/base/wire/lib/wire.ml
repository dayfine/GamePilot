(* The protocol's public face: the codec lives in one module per message
   family, re-exported here in the order the types were first defined. *)

type json = Yojson.Safe.t

exception Decode_error = Json_fields.Decode_error

type button = Command.button =
  | A
  | B
  | Select
  | Start
  | Right
  | Left
  | Up
  | Down
  | R
  | L

let string_of_button = Command.string_of_button
let button_of_string = Command.button_of_string

type command = Command.command =
  | Press of { buttons : button list; hold_ms : int; cooldown_ms : int }
  | Wait of { wait_ms : int }

type box = Probe.box = { x : float; y : float; w : float; h : float }
type delivery = Probe.delivery = Every | Latest

type color_range = Probe.color_range = {
  min : int * int * int;
  max : int * int * int;
}

type probe_spec = Probe.probe_spec = {
  id : string;
  kind : string;
  box : box;
  delivery : delivery;
  template : string option;
  ink : color_range option;
  color_range : color_range option;
}

let color_stats_probe = Probe.color_stats_probe
let template_match_probe = Probe.template_match_probe
let color_count_probe = Probe.color_count_probe

type rgb = Probe.rgb = { r : float; g : float; b : float }

type probe_result = Probe.probe_result =
  | Color_stats of { mean : rgb; stddev : rgb }
  | Template_match of { score : float; x : float; y : float }
  | Color_count of { fraction : float; mean : rgb option }
  | Other of json

type frame = Probe.frame = {
  seq : int;
  t_ms : float;
  probes : (string * probe_result) list;
}

type batch_done = Command.batch_done = {
  batch_id : string;
  seq : int;
  t_ms : float;
}

type backend = Backend.backend = {
  kind : string;
  game_code : string;
  frame_rate : float;
  width : int;
  height : int;
  viewport : Probe.box;
  game_width : int;
  game_height : int;
}

type hello_result = Backend.hello_result = {
  protocol : int;
  daemon : string;
  backend : backend;
  probe_kinds : string list;
}

type submit_result = Command.submit_result = {
  batch_id : string;
  start_seq : int;
}

type error = Jsonrpc.error = {
  code : int;
  message : string;
  data : json option;
}

type call = Jsonrpc.call =
  | Hello of { protocol : int; client : string }
  | Load_state of { path : string }
  | Upload_template of { png : string }
  | Subscribe of probe_spec list
  | Unsubscribe of string list
  | Submit of { batch_id : string; commands : command list }
  | Cancel

type request = Jsonrpc.request = { id : int; call : call }
type response = Jsonrpc.response = { id : int; outcome : (json, error) result }

type notification = Jsonrpc.notification =
  | Frame of { load : int; frame : frame }
  | Batch_done of batch_done

type message = Jsonrpc.message =
  | Request of request
  | Response of response
  | Notification of notification

let method_name = Jsonrpc.method_name
let message_of_json = Jsonrpc.message_of_json
let json_of_message = Jsonrpc.json_of_message
let message_of_string = Jsonrpc.message_of_string
let string_of_message = Jsonrpc.string_of_message
let hello_result_of_json = Backend.hello_result_of_json
let json_of_hello_result = Backend.json_of_hello_result

type load_state_result = Backend.load_state_result = { seq : int; load : int }

let load_state_result_of_json = Backend.load_state_result_of_json
let json_of_load_state_result = Backend.json_of_load_state_result
let upload_template_result_of_json = Probe.upload_template_result_of_json
let json_of_upload_template_result = Probe.json_of_upload_template_result
let subscribe_result_of_json = Probe.subscribe_result_of_json
let json_of_subscribe_result = Probe.json_of_subscribe_result
let unsubscribe_result_of_json = Probe.unsubscribe_result_of_json
let json_of_unsubscribe_result = Probe.json_of_unsubscribe_result
let submit_result_of_json = Command.submit_result_of_json
let json_of_submit_result = Command.json_of_submit_result
let cancel_result_of_json = Command.cancel_result_of_json
let json_of_cancel_result = Command.json_of_cancel_result

type direction = Wire_log.direction = In | Out

type log_line = Wire_log.log_line = {
  dir : direction;
  t_ms : float;
  msg : message;
}

let log_line_of_json = Wire_log.log_line_of_json
let json_of_log_line = Wire_log.json_of_log_line

type image_probes = Probe_images.image_probes

let image_probes_of_json = Probe_images.image_probes_of_json
let image_probes_of_string = Probe_images.image_probes_of_string
let read_image_probes = Probe_images.read_image_probes
