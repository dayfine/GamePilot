(** Wire protocol v1.21 (protocol/v1): message types and their JSON codec.

    The codec lives in one module per message family ([Command], [Probe],
    [Backend], [Jsonrpc], [Wire_log], [Probe_images]); this module re-exports
    it.

    One JSON object per line. The golden files in [protocol/v1] are the spec;
    [test/test_wire.ml] decodes and re-encodes every one of them. *)

type json = Yojson.Safe.t
(** A decoded JSON value: a message, or a result or notification's part. *)

exception Decode_error of string
(** Raised by every [*_of_json] function on a message that does not match the
    protocol. The string names the offending field. *)

(** {1 Values} *)

(** A controller button a command presses ({!Command.button}). *)
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
  | Home
  | X
  | Y
  | ZL
  | ZR
  | Plus
  | Minus
  | LStick

val all_buttons : button list
(** Every button, in the daemon's bit order (protocol/v1). *)

val string_of_button : button -> string
(** The button's name on the wire, the constructor's own (["ZL"]). *)

val button_of_string : string -> button option
(** The button a wire name stands for; [None] for an unknown name. *)

val switch_only : button -> bool
(** [Home], [X], [Y] (v1.11), [ZL] (v1.14), [ZR] (v1.16), [Plus] and [Minus]
    (v1.17): buttons only the Switch backend takes. [Plus] and [Minus] are the
    Switch's names; [Start] and [Select] are the GBA's, which the Switch backend
    presses as Plus and Minus (the Switch's GBA app maps them so). [LStick]
    (v1.18) is the left stick's click: the Switch keyboard's Shift. *)

type stick = Command.stick
(** A stick's tilt (x, y) in -1..1: +x right, +y up (v1.12). *)

val stick : float -> float -> (stick, string) result
(** [stick x y]; an error when [x] or [y] is outside -1..1 or not a number. *)

(** One step of a [submit] batch, which the daemon runs in order. *)
type command = Command.command =
  | Press of {
      buttons : button list;
      left_stick : stick option;
      right_stick : stick option;
      hold_ms : int;
      cooldown_ms : int;
    }
      (** [buttons] held and the sticks tilted for [hold_ms], then all released
          and centred for [cooldown_ms]; a stick left out ([None]) is centred
          (sticks: v1.12, the Switch only). *)
  | Wait of { wait_ms : int }
      (** Presses nothing for [wait_ms], everything released. *)

val press :
  ?left_stick:stick ->
  ?right_stick:stick ->
  hold_ms:int ->
  cooldown_ms:int ->
  button list ->
  command
(** [press ~hold_ms ~cooldown_ms buttons] is a {!Press}; each stick is centred
    ([None]) unless given. Build presses with this rather than the record. *)

type box = Probe.box = { x : float; y : float; w : float; h : float }
(** Normalized, 0..1. A probe's box is relative to the game picture (the [hello]
    backend's [viewport]), not to the frame. *)

(** How often a probe's results reach the client: on [Every] captured frame,
    none skipped, or on the [Latest] when the client is ready. *)
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
      (** [core.template_match@1], [core.template_ncc@1] and [core.find@1] only:
          the hash [probe.upload_template] returned on this connection. *)
  ink : color_range option;
      (** [core.template_match@1] only: compare the masks of the pixels in this
          range instead of the colors. *)
  skip_seams : bool;
      (** [core.template_match@1] with [ink] only: leave out of the comparison
          the scaled template mask's seam pixels, which straddle two game
          pixels; [false] for every other probe. *)
  color_range : color_range option;  (** [core.color_count@1] only *)
  test : Line_shares.test;  (** [core.line_shares@1] only; else [[]] *)
  find : Blob_find.params option;  (** [core.find@1] only *)
}
(** [kind] is an open set, e.g. ["core.color_stats@1"]. Programs build specs
    with the constructors below. *)

val color_stats_probe : id:string -> box:box -> delivery:delivery -> probe_spec
(** [core.color_stats@1]: mean and stddev over [box]. A black screen is this
    probe with a reader's threshold; there is no daemon kind for it. *)

val template_match_probe :
  ?ink:color_range ->
  ?skip_seams:bool ->
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
    whatever its color and shading. With [skip_seams] (default [false], ignored
    without [ink]) the score counts only the scaled template mask's whole
    pixels: at a fractional scale (6.5 on the Switch's GBA picture) a seam pixel
    of the mask holds a blend that a binary box mask can only half agree with,
    which costs about 1/4 of a pixel whatever the frame shows. *)

val template_ncc_probe :
  id:string -> box:box -> delivery:delivery -> template:string -> probe_spec
(** [core.template_ncc@1]: grayscale zero-mean normalized cross-correlation
    ([-1..1], higher is better) of an uploaded template inside [box]. *)

val color_count_probe :
  id:string ->
  box:box ->
  delivery:delivery ->
  min:int * int * int ->
  max:int * int * int ->
  probe_spec
(** [core.color_count@1]: the share of [box]'s pixels whose every channel lies
    in [min..max] (inclusive), and their mean color. *)

module Line_shares = Line_shares
(** [core.line_shares@1]'s pixel test and result. *)

module Blob_find = Blob_find
(** [core.find@1]'s params and blobs. *)

val line_shares_probe :
  id:string ->
  box:box ->
  delivery:delivery ->
  test:Line_shares.test ->
  (probe_spec, string) result
(** [core.line_shares@1]: the share of [box]'s pixels passing every comparison
    of [test], per row and per column of the box's frame pixels; [Error] for an
    empty test. *)

val find_probe :
  ?template:string ->
  id:string ->
  box:box ->
  delivery:delivery ->
  Blob_find.params ->
  probe_spec
(** [core.find@1]: the blobs in [box] that pass the params' filters, with the
    scores they ask for; [template] (an uploaded hash, used at its own size with
    its alpha) asks for each blob's [score]. *)

type rgb = Probe.rgb = { r : float; g : float; b : float }
(** A colour measured over many pixels, each channel on 0..255. *)

(** Decoded by the result's [kind] field, not by its shape. *)
type probe_result = Probe.probe_result =
  | Color_stats of { mean : rgb; stddev : rgb }  (** [core.color_stats@1] *)
  | Template_match of { score : float; x : float; y : float }
      (** [core.template_match@1]: [score] is the mean squared difference per
          pixel and channel over 255² (with ink, of the masks), 0 = identical,
          lower is better; [x], [y] the placement's top-left corner, normalized
          to the game picture. *)
  | Template_ncc of { score : float; x : float; y : float }
      (** [core.template_ncc@1]: [score] is the grayscale zero-mean normalized
          cross-correlation in [-1..1] (higher is better); [x], [y] the
          placement's top-left corner, normalized to the game picture. *)
  | Color_count of { fraction : float; mean : rgb option }
      (** [core.color_count@1]: pixels in range over pixels in the box, and the
          mean of those in range ([None] when there are none). *)
  | Line_shares of Line_shares.t
      (** [core.line_shares@1]: each row's and each column's share of the box's
          pixels passing the probe's test. *)
  | Find of { blobs : Blob_find.blob list }
      (** [core.find@1]: the blobs that passed the probe's filters, with the
          scores its params asked for; [[]] when none did. *)
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
(** A [batch_done] notification: the batch [batch_id] has run all its commands,
    as of frame [seq] at [t_ms] on the daemon clock. *)

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
(** What the daemon drives, from [hello]: the backend, the game, the frame's
    size and where the game picture sits in it ({!Backend.backend}). *)

type hello_result = Backend.hello_result = {
  protocol : int;
  daemon : string;
  backend : backend;
  probe_kinds : string list;
}
(** The daemon's answer to [hello]: the protocol version, its own name and
    version, what it drives and the probe kinds it runs. *)

type submit_result = Command.submit_result = {
  batch_id : string;
  start_seq : int;
}
(** The answer to [submit]: the batch taken, and the frame it starts on. *)

type error = Jsonrpc.error = {
  code : int;
  message : string;
  data : json option;
}
(** A JSON-RPC error answer: its code, a message for a person, and the details
    some errors carry (a lease refusal's holder). *)

(** {1 Messages} *)

(** A request's method and its params: what a client asks the daemon to do
    ({!Jsonrpc.call}). *)
type call = Jsonrpc.call =
  | Hello of { protocol : int; client : string }
  | Load_state of { path : string }
  | Reset
      (** (v1.19) Resets the machine as its power switch would ([backend.reset],
          mGBA only); answered like [Load_state]. *)
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
  | Submit of {
      batch_id : string;
      start_at_t_ms : float option;
      commands : command list;
    }
  | Cancel
  | Cancel_then of { batch_id : string; commands : command list }
      (** (v1.15) [cancel] with [then]: drops the queued commands with no
          release and starts this batch in their place, the buttons both hold
          staying held (the fork's command dispatched over a running one) *)
  | Status  (** the daemon's health; served to every client *)
  | Lease_acquire of { owner : string; ttl_ms : int option }
      (** takes the input lease for this connection, or renews it; [ttl_ms]
          defaults to the daemon's (60 s) *)
  | Lease_release

type request = Jsonrpc.request = { id : int; call : call }
(** A call with the id its response will carry. *)

type response = Jsonrpc.response = { id : int; outcome : (json, error) result }
(** A response does not name its method (JSON-RPC pairs it with its request by
    [id]); decode [Ok] with the [*_result] decoder for that request's method. *)

type gap = Jsonrpc.gap = {
  from_seq : int;
  to_seq : int;
  from_t_ms : float;
  to_t_ms : float;
}
(** A [gap] notification (v1.21): frame sequence numbers [from_seq..to_seq]
    (inclusive) were missed while an [every] probe was subscribed, between
    [from_t_ms] and [to_t_ms]. *)

(** A message no one answers, from the daemon or from the program. *)
type notification = Jsonrpc.notification =
  | Frame of { load : int; frame : frame }
      (** [frame]: how many [backend.load_state] calls had succeeded when the
          daemon took the frame. Session bookkeeping, not a measurement, so it
          stays out of {!frame}. *)
  | Gap of gap
      (** [gap], from the daemon: skipped frames under [delivery: "every"]. *)
  | Batch_done of batch_done
  | Watch_plan of Watch.plan
      (** From the program: its checkpoint's events and their states, for the
          watch page. The daemon keeps it off the wire log. *)
  | Watch_log of string
      (** From the program: one story log line, for the watch page; off the wire
          log too. *)
  | Watch_run of Watch_run.t
      (** From the program: the chain of checkpoints it runs and the current
          one's trials, for the watch page; off the wire log too. *)
  | Stop of string
      (** From the daemon: someone pressed Stop on the watch page (the reason).
          The daemon has already cancelled the queued commands and released
          every button; the program ends at its next wait. *)
  | Keepawake of { key : string; idle_ms : int }
      (** In the wire log only (a [Daemon] line), never sent: the daemon pressed
          [key] to keep the console awake after [idle_ms] with no input
          (daemon/src/keep_awake.h). *)

(** Any JSON-RPC message: a request, its response, or a notification. *)
type message = Jsonrpc.message =
  | Request of request
  | Response of response
  | Notification of notification

val method_name : call -> string
(** The call's method on the wire, e.g. ["backend.load_state"]. *)

val message_of_json : json -> message
(** One decoded message; an unknown method or a malformed envelope or params is
    a [Decode_error]. *)

val json_of_message : message -> json
(** One message, as {!message_of_json} reads it. *)

val message_of_string : string -> message
(** Parses one line. Raises [Decode_error] on bad JSON too. *)

val string_of_message : message -> string
(** One line, no trailing newline. *)

(** {1 Results} *)

val hello_result_of_json : json -> hello_result
(** The [hello] result. *)

val json_of_hello_result : hello_result -> json
(** The [hello] result, as {!hello_result_of_json} reads it. *)

type load_state_result = Backend.load_state_result = { seq : int; load : int }
(** The [seq] after loading and the daemon's new [load] count. *)

val load_state_result_of_json : json -> load_state_result
(** The [backend.load_state] (or [backend.reset]) result. *)

val json_of_load_state_result : load_state_result -> json
(** The [backend.load_state] result, as {!load_state_result_of_json} reads it.
*)

val save_result_of_json : json -> int
(** The [seq] of the frame a [backend.save_state] or [backend.save_frame] saved.
*)

val json_of_save_result : int -> json
(** [{"seq": n}], as {!save_result_of_json} reads it. *)

val upload_template_result_of_json : json -> string
(** The template's hash: lowercase hex SHA-256 of the PNG bytes. *)

val json_of_upload_template_result : string -> json
(** The [probe.upload_template] result for this hash. *)

val subscribe_result_of_json : json -> string list
(** The [subscribe] result: the ids of the probes now subscribed. *)

val json_of_subscribe_result : string list -> json
(** The [subscribe] result, [{"subscribed": [ids]}]. *)

val unsubscribe_result_of_json : json -> string list
(** The ids that were subscribed and are now removed. *)

val json_of_unsubscribe_result : string list -> json
(** The [unsubscribe] result, [{"unsubscribed": [ids]}]. *)

val submit_result_of_json : json -> submit_result
(** The [submit] result. *)

val json_of_submit_result : submit_result -> json
(** The [submit] result, as {!submit_result_of_json} reads it. *)

val cancel_result_of_json : json -> int
(** The [cancel] result's [released_seq]: the frame on which every button was
    released. *)

val json_of_cancel_result : int -> json
(** The [cancel] result, [{"released_seq": n}]. *)

module Watch = Watch

module Watch_run = Watch_run
(** The watch page's plan and log notifications. *)

module Watch_registry = Watch_registry
(** The registry of live watch pages ([gamepilot runs]). *)

module Daemon_status = Daemon_status
(** The [status] result: decode it with [Daemon_status.of_json]. *)

module Lease = Lease
(** The input lease: [lease.acquire] and [lease.release] results, refusals. *)

(** {1 Wire log} *)

(** Which way a logged message went ([dir] on the wire). *)
type direction = Wire_log.direction =
  | In  (** from the client *)
  | Out  (** to the client *)
  | Daemon
      (** the daemon's own act, sent to no one: its keep-awake press. Replay
          skips it. *)

type log_line = Wire_log.log_line = {
  dir : direction;
  t_ms : float;
  conn : int option;
  owner : string option;
  msg : message;
}
(** One line of the daemon's wire log: one message, which way it went, when
    (daemon clock), on which connection and, for input, under whose lease. *)

val log_line_of_json : json -> log_line
(** One wire log line; a missing field or an unknown [dir] is a [Decode_error].
*)

val json_of_log_line : log_line -> json
(** One wire log line, as {!log_line_of_json} reads it. *)

(** {1 Probing saved images} *)

type image_probes = string * (string * probe_result) list
(** One line of the daemon's offline [probe_images] tool
    ([{"image": path, "probes": {id: result}}]): the image's path as printed and
    its probe results by id, as in a {!frame}. *)

val image_probes_of_json : json -> image_probes
(** One line of the tool's output. *)

val image_probes_of_string : string -> image_probes list
(** The tool's whole output, one image per non-blank line, in order. *)

val read_image_probes : string -> image_probes list
(** Reads the tool's output file at this path. *)
