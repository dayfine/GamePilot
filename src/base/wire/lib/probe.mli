(** Probe specs, probe results, the [frame] that carries them, and the
    [probe.upload_template], [subscribe] and [unsubscribe] results. *)

type json = Yojson.Safe.t
type box = { x : float; y : float; w : float; h : float }

val box_of_json : json -> box
val json_of_box : box -> json

type delivery = Every | Latest
type color_range = { min : int * int * int; max : int * int * int }

type probe_spec = {
  id : string;
  kind : string;
  box : box;
  delivery : delivery;
  template : string option;
  ink : color_range option;
  color_range : color_range option;
  test : Line_shares.test;
  find : Blob_find.params option;
}

val color_stats_probe : id:string -> box:box -> delivery:delivery -> probe_spec

val template_match_probe :
  ?ink:color_range ->
  id:string ->
  box:box ->
  delivery:delivery ->
  template:string ->
  unit ->
  probe_spec

val color_count_probe :
  id:string ->
  box:box ->
  delivery:delivery ->
  min:int * int * int ->
  max:int * int * int ->
  probe_spec

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
val json_of_probe_spec : probe_spec -> json

type rgb = { r : float; g : float; b : float }

type probe_result =
  | Color_stats of { mean : rgb; stddev : rgb }
  | Template_match of { score : float; x : float; y : float }
  | Color_count of { fraction : float; mean : rgb option }
  | Line_shares of Line_shares.t  (** [core.line_shares@1] *)
  | Find of { blobs : Blob_find.blob list }  (** [core.find@1] *)
  | Other of json  (** a kind this side does not know, kept verbatim *)

val probes_of_json : string -> json -> (string * probe_result) list
(** A [probes] object [{id: result}], in its order; [what] names it in errors.
*)

val json_of_probes : (string * probe_result) list -> json

type frame = { seq : int; t_ms : float; probes : (string * probe_result) list }

val frame_of_json : json -> frame
val json_of_frame : load:int -> frame -> json
val upload_template_result_of_json : json -> string
val json_of_upload_template_result : string -> json
val subscribe_result_of_json : json -> string list
val json_of_subscribe_result : string list -> json
val unsubscribe_result_of_json : json -> string list
val json_of_unsubscribe_result : string list -> json
