(** Wire protocol v1.4 (contracts/v1): message types and their JSON codec.

    The codec lives in one module per message family ([Command], [Probe],
    [Backend], [Jsonrpc], [Wire_log], [Probe_images]); this module re-exports
    it.

    One JSON object per line. The golden files in [contracts/v1] are the spec;
    [test/test_wire.ml] decodes and re-encodes every one of them. *)

type json = Yojson.Safe.t

exception Decode_error of string
(** Raised by every [*_of_json] function on a message that does not match the
    protocol. The string names the offending field. *)

(** {1 Values} *)

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

val string_of_button : button -> string
val button_of_string : string -> button option

type command = Command.command =
  | Press of { buttons : button list; hold_ms : int; cooldown_ms : int }
  | Wait of { wait_ms : int }

type box = Probe.box = { x : float; y : float; w : float; h : float }
(** Normalized, 0..1. A probe's box is relative to the game picture (the [hello]
    backend's [viewport]), not to the frame. *)

type delivery = Probe.delivery = Every | Latest

type color_range = Probe.color_range = {
  min : int * int * int;
  max : int * int * int;
}
(** An inclusive (r, g, b) range, 0..255 per channel. *)

type probe_spec = Probe.probe_spec = {
  id : string;
  kind : string;
  box : box;
  delivery : delivery;
  template : string option;
      (** [core.template_match@1] only: the hash [probe.upload_template]
          returned on this connection. *)
  ink : color_range option;
      (** [core.template_match@1] only: compare the masks of the pixels in this
          range instead of the colors. *)
  color_range : color_range option;  (** [core.color_count@1] only *)
}
(** [kind] is an open set, e.g. ["core.color_stats@1"]. Programs build specs
    with the constructors below. *)

val color_stats_probe : id:string -> box:box -> delivery:delivery -> probe_spec
(** [core.color_stats@1]: mean and stddev over [box]. A black screen is this
    probe with a reader's threshold; there is no daemon kind for it. *)

val template_match_probe :
  ?ink:color_range ->
  id:string ->
  box:box ->
  delivery:delivery ->
  template:string ->
  unit ->
  probe_spec
(** [core.template_match@1]: the best placement of an uploaded template inside
    [box]. [template] is the hash from {!upload_template_result_of_json}; the
    PNG is in game pixels and the daemon scales it to the frame. With [ink] the
    daemon compares the masks of the template's and the box's pixels inside that
    range (the score is then the fraction of differing pixels), so text matches
    whatever its color and shading. *)

val color_count_probe :
  id:string ->
  box:box ->
  delivery:delivery ->
  min:int * int * int ->
  max:int * int * int ->
  probe_spec
(** [core.color_count@1]: the share of [box]'s pixels whose every channel lies
    in [min..max] (inclusive), and their mean color. *)

type rgb = Probe.rgb = { r : float; g : float; b : float }

(** Decoded by the result's [kind] field, not by its shape. *)
type probe_result = Probe.probe_result =
  | Color_stats of { mean : rgb; stddev : rgb }  (** [core.color_stats@1] *)
  | Template_match of { score : float; x : float; y : float }
      (** [core.template_match@1]: [score] is the mean squared difference per
          pixel and channel over 255² (with ink, of the masks), 0 = identical,
          lower is better; [x], [y] the placement's top-left corner, normalized
          to the game picture. *)
  | Color_count of { fraction : float; mean : rgb option }
      (** [core.color_count@1]: pixels in range over pixels in the box, and the
          mean of those in range ([None] when there are none). *)
  | Other of json  (** a kind this side does not know yet, kept verbatim *)

type frame = Probe.frame = {
  seq : int;
  t_ms : float;
  probes : (string * probe_result) list;
}
(** One [frame] notification. [probes] keeps the daemon's order and holds only
    the results that changed since the previous frame (all of them on the first
    frame after a subscribe or a load); the session fills in the rest. *)

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
  height : int;  (** the frame's size in pixels *)
  viewport : box;
      (** where the game picture sits in the frame, normalized to it; probe
          boxes are relative to this (the whole frame on mGBA) *)
  game_width : int;
  game_height : int;
      (** the picture's native size in game pixels ([game_size] on the wire,
          240x160 on the GBA); templates are in these *)
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

(** {1 Messages} *)

type call = Jsonrpc.call =
  | Hello of { protocol : int; client : string }
  | Load_state of { path : string }
  | Save_state of { path : string }
      (** Saves the emulator's state to [path] (a dev-loop op: a checkpoint's
          end saved as the next one's start). *)
  | Save_frame of { path : string }
      (** Writes the current frame to [path] as a PNG (a failure frame). *)
  | Upload_template of { png : string }
      (** [png]: the PNG file's bytes (base64 on the wire). *)
  | Subscribe of probe_spec list
  | Unsubscribe of string list
      (** probe ids; the daemon stops measuring them *)
  | Submit of { batch_id : string; commands : command list }
  | Cancel

type request = Jsonrpc.request = { id : int; call : call }

type response = Jsonrpc.response = { id : int; outcome : (json, error) result }
(** A response does not name its method (JSON-RPC pairs it with its request by
    [id]); decode [Ok] with the [*_result] decoder for that request's method. *)

type notification = Jsonrpc.notification =
  | Frame of { load : int; frame : frame }
      (** [load]: how many [backend.load_state] calls had succeeded when the
          daemon took the frame. Session bookkeeping, not a measurement, so it
          stays out of {!frame}. *)
  | Batch_done of batch_done

type message = Jsonrpc.message =
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

type load_state_result = Backend.load_state_result = { seq : int; load : int }
(** The [seq] after loading and the daemon's new [load] count. *)

val load_state_result_of_json : json -> load_state_result
val json_of_load_state_result : load_state_result -> json

val save_result_of_json : json -> int
(** The [seq] of the frame a [backend.save_state] or [backend.save_frame] saved.
*)

val json_of_save_result : int -> json

val upload_template_result_of_json : json -> string
(** The template's hash: lowercase hex SHA-256 of the PNG bytes. *)

val json_of_upload_template_result : string -> json
val subscribe_result_of_json : json -> string list
val json_of_subscribe_result : string list -> json

val unsubscribe_result_of_json : json -> string list
(** The ids that were subscribed and are now removed. *)

val json_of_unsubscribe_result : string list -> json
val submit_result_of_json : json -> submit_result
val json_of_submit_result : submit_result -> json

val cancel_result_of_json : json -> int
(** The [released_seq]. *)

val json_of_cancel_result : int -> json

(** {1 Wire log} *)

type direction = Wire_log.direction =
  | In  (** from the client *)
  | Out  (** to the client *)

type log_line = Wire_log.log_line = {
  dir : direction;
  t_ms : float;
  msg : message;
}

val log_line_of_json : json -> log_line
val json_of_log_line : log_line -> json

(** {1 Probing saved images} *)

type image_probes = string * (string * probe_result) list
(** One line of the daemon's offline [probe_images] tool
    ([{"image": path, "probes": {id: result}}]): the image's path as printed and
    its probe results by id, as in a {!frame}. *)

val image_probes_of_json : json -> image_probes

val image_probes_of_string : string -> image_probes list
(** The tool's whole output, one image per non-blank line, in order. *)

val read_image_probes : string -> image_probes list
(** Reads the tool's output file at this path. *)
