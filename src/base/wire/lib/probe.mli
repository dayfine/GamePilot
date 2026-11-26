(** Probe specs, probe results, the [frame] that carries them, and the
    [probe.upload_template], [subscribe] and [unsubscribe] results. *)

type json = Yojson.Safe.t
(** A decoded JSON value: a probe spec, a [frame]'s params or a result. *)

type box = { x : float; y : float; w : float; h : float }
(** Where a probe looks: left, top, width and height, normalized 0..1 to the
    game picture (the [hello] backend's [viewport]), not to the frame. *)

val box_of_json : json -> box
(** A box object [{x, y, w, h}]; a missing field is a [Decode_error]. *)

val json_of_box : box -> json
(** A box object, as {!box_of_json} reads it. *)

(** How often a probe's results reach the client ([delivery] on the wire). *)
type delivery =
  | Every
      (** ["every"]: on every captured frame, none skipped (the daemon's
          [status] then says ["full"] fidelity) *)
  | Latest
      (** ["latest"]: on the newest frame when the client is ready; frames
          between may be skipped *)

type color_range = { min : int * int * int; max : int * int * int }
(** An inclusive (r, g, b) range, 0..255 per channel: a pixel is in it when each
    channel lies between [min]'s and [max]'s. *)

type probe_spec = {
  id : string;
  kind : string;  (** an open set, e.g. ["core.color_stats@1"] *)
  box : box;
  delivery : delivery;
  template : string option;
      (** [core.template_match@1] and [core.find@1] only: the hash
          [probe.upload_template] returned on this connection. *)
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
(** One probe a client subscribes: its [id] (which names its results), its
    [kind], its [box] and [delivery], and the settings of its kind; the other
    kinds' settings are [None] (or [[]]). *)

val color_stats_probe : id:string -> box:box -> delivery:delivery -> probe_spec
(** A [core.color_stats@1] probe: the mean and standard deviation of [box]'s
    colour. *)

val template_match_probe :
  ?ink:color_range ->
  ?skip_seams:bool ->
  id:string ->
  box:box ->
  delivery:delivery ->
  template:string ->
  unit ->
  probe_spec
(** A [core.template_match@1] probe: the best placement inside [box] of the
    uploaded template whose hash is [template]; with [ink], it compares which
    pixels lie in that range instead of their colours, and with [skip_seams]
    (default [false]; ignored without [ink]) only the scaled mask's whole
    pixels. *)

val color_count_probe :
  id:string ->
  box:box ->
  delivery:delivery ->
  min:int * int * int ->
  max:int * int * int ->
  probe_spec
(** A [core.color_count@1] probe: the share of [box]'s pixels within [min..max],
    and their mean colour. *)

val line_shares_probe :
  id:string ->
  box:box ->
  delivery:delivery ->
  test:Line_shares.test ->
  (probe_spec, string) result
(** [Error] for an empty test, which the daemon refuses. *)

val find_probe :
  ?template:string ->
  id:string ->
  box:box ->
  delivery:delivery ->
  Blob_find.params ->
  probe_spec
(** [core.find@1] over [box] with these params; [template] asks for each blob's
    [score]. *)

val probe_spec_of_json : json -> probe_spec
(** One probe of a [subscribe] request; a missing field, an unknown delivery or
    a kind's bad settings is a [Decode_error]. *)

val json_of_probe_spec : probe_spec -> json
(** One probe of a [subscribe] request, as {!probe_spec_of_json} reads it;
    settings that are [None] (or [[]]) are left out. *)

type rgb = { r : float; g : float; b : float }
(** A colour measured over many pixels, each channel on 0..255 (fractional, as a
    mean or a deviation is). *)

(** What one probe measured on one frame, by its kind. *)
type probe_result =
  | Color_stats of { mean : rgb; stddev : rgb }
      (** [core.color_stats@1]: the box's mean colour and its standard deviation
          per channel *)
  | Template_match of { score : float; x : float; y : float }
      (** [core.template_match@1]: the best placement's difference from the
          template (0 = identical, lower is better) and its top-left corner,
          normalized to the game picture *)
  | Color_count of { fraction : float; mean : rgb option }
      (** [core.color_count@1]: the box's pixels in range over all its pixels,
          and the mean of those in range ([None] when there are none) *)
  | Line_shares of Line_shares.t  (** [core.line_shares@1] *)
  | Find of { blobs : Blob_find.blob list }  (** [core.find@1] *)
  | Other of json  (** a kind this side does not know, kept verbatim *)

val probes_of_json : string -> json -> (string * probe_result) list
(** A [probes] object [{id: result}], in its order; [what] names it in errors.
*)

val json_of_probes : (string * probe_result) list -> json
(** A [probes] object, as {!probes_of_json} reads it. *)

type frame = { seq : int; t_ms : float; probes : (string * probe_result) list }
(** One captured frame's measurements: its number [seq] (1, 2, ... in capture
    order), when it was taken on the daemon clock, and its probe results by
    probe id. *)

val frame_of_json : json -> frame
(** A [frame] notification's params; its [load] is not part of the frame. *)

val json_of_frame : load:int -> frame -> json
(** A [frame] notification's params, with the daemon's [load] count. *)

val upload_template_result_of_json : json -> string
(** The [probe.upload_template] result: the template's hash, which template
    probes name. *)

val json_of_upload_template_result : string -> json
(** The [probe.upload_template] result, as {!upload_template_result_of_json}
    reads it. *)

val subscribe_result_of_json : json -> string list
(** The [subscribe] result: the ids of the probes now subscribed. *)

val json_of_subscribe_result : string list -> json
(** The [subscribe] result, [{"subscribed": [ids]}]. *)

val unsubscribe_result_of_json : json -> string list
(** The [unsubscribe] result: the ids that were subscribed and are now removed.
*)

val json_of_unsubscribe_result : string list -> json
(** The [unsubscribe] result, [{"unsubscribed": [ids]}]. *)
