open Json_fields

type json = Yojson.Safe.t
type box = { x : float; y : float; w : float; h : float }

let box_of_json j =
  let f = float_field "box" in
  { x = f "x" j; y = f "y" j; w = f "w" j; h = f "h" j }

let json_of_box { x; y; w; h } =
  `Assoc [ ("x", `Float x); ("y", `Float y); ("w", `Float w); ("h", `Float h) ]

type delivery = Every | Latest

let delivery_of_string = function
  | "every" -> Every
  | "latest" -> Latest
  | s -> fail "probe.delivery: unknown value %S" s

let string_of_delivery = function Every -> "every" | Latest -> "latest"

type probe_spec = {
  id : string;
  kind : string;
  box : box;
  delivery : delivery;
  template : string option;
}

let color_stats_kind = "core.color_stats@1"
let template_match_kind = "core.template_match@1"

let color_stats_probe ~id ~box ~delivery =
  { id; kind = color_stats_kind; box; delivery; template = None }

let template_match_probe ~id ~box ~delivery ~template =
  { id; kind = template_match_kind; box; delivery; template = Some template }

let probe_spec_of_json j =
  let what = "probe" in
  {
    id = string_field what "id" j;
    kind = string_field what "kind" j;
    box = box_of_json (field what "box" j);
    delivery = delivery_of_string (string_field what "delivery" j);
    template =
      Option.map (to_string "probe.template") (field_opt what "template" j);
  }

let json_of_template = function
  | Some t -> [ ("template", `String t) ]
  | None -> []

let json_of_probe_spec { id; kind; box; delivery; template } =
  `Assoc
    ([
       ("id", `String id);
       ("kind", `String kind);
       ("box", json_of_box box);
       ("delivery", `String (string_of_delivery delivery));
     ]
    @ json_of_template template)

type rgb = { r : float; g : float; b : float }

let rgb_of_json what j =
  match to_list what j with
  | [ r; g; b ] ->
      { r = to_float what r; g = to_float what g; b = to_float what b }
  | _ -> fail "%s: expected [r, g, b]" what

let json_of_rgb { r; g; b } = `List [ `Float r; `Float g; `Float b ]

type probe_result =
  | Color_stats of { mean : rgb; stddev : rgb }
  | Template_match of { score : float; x : float; y : float }
  | Other of json

let color_stats_of_json what j =
  Color_stats
    {
      mean = rgb_of_json "probe.mean" (field what "mean" j);
      stddev = rgb_of_json "probe.stddev" (field what "stddev" j);
    }

let template_match_of_json what j =
  let f = float_field what in
  Template_match { score = f "score" j; x = f "x" j; y = f "y" j }

let probe_result_of_json j =
  let what = "probe result" in
  match string_field what "kind" j with
  | kind when kind = color_stats_kind -> color_stats_of_json what j
  | kind when kind = template_match_kind -> template_match_of_json what j
  | _ -> Other j

let json_of_color_stats ~mean ~stddev =
  `Assoc
    [
      ("kind", `String color_stats_kind);
      ("mean", json_of_rgb mean);
      ("stddev", json_of_rgb stddev);
    ]

let json_of_template_match ~score ~x ~y =
  `Assoc
    [
      ("kind", `String template_match_kind);
      ("score", `Float score);
      ("x", `Float x);
      ("y", `Float y);
    ]

let json_of_probe_result = function
  | Color_stats { mean; stddev } -> json_of_color_stats ~mean ~stddev
  | Template_match { score; x; y } -> json_of_template_match ~score ~x ~y
  | Other j -> j

let probes_of_json what j =
  List.map (fun (id, v) -> (id, probe_result_of_json v)) (fields what j)

let json_of_probes probes =
  `Assoc (List.map (fun (id, r) -> (id, json_of_probe_result r)) probes)

type frame = { seq : int; t_ms : float; probes : (string * probe_result) list }

let frame_of_json j =
  let what = "frame" in
  {
    seq = int_field what "seq" j;
    t_ms = float_field what "t_ms" j;
    probes = probes_of_json "frame.probes" (field what "probes" j);
  }

let json_of_frame ~load { seq; t_ms; probes } =
  `Assoc
    [
      ("seq", `Int seq);
      ("load", `Int load);
      ("t_ms", `Float t_ms);
      ("probes", json_of_probes probes);
    ]

let upload_template_result_of_json j =
  string_field "probe.upload_template.result" "template" j

let json_of_upload_template_result hash = `Assoc [ ("template", `String hash) ]

let subscribe_result_of_json j =
  string_list_field "subscribe.result" "subscribed" j

let json_of_subscribe_result ids =
  `Assoc [ ("subscribed", json_of_strings ids) ]
