(** Probe specs, probe results, the [frame] that carries them, and the
    [probe.upload_template] and [subscribe] results. *)

type json = Yojson.Safe.t
type box = { x : float; y : float; w : float; h : float }
type delivery = Every | Latest

type probe_spec = {
  id : string;
  kind : string;
  box : box;
  delivery : delivery;
  template : string option;
}

val color_stats_probe : id:string -> box:box -> delivery:delivery -> probe_spec

val template_match_probe :
  id:string -> box:box -> delivery:delivery -> template:string -> probe_spec

val probe_spec_of_json : json -> probe_spec
val json_of_probe_spec : probe_spec -> json

type rgb = { r : float; g : float; b : float }

type probe_result =
  | Color_stats of { mean : rgb; stddev : rgb }
  | Template_match of { score : float; x : float; y : float }
  | Other of json

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
