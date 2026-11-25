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

let color_stats_kind = "core.color_stats@1"
let template_match_kind = "core.template_match@1"
let color_count_kind = "core.color_count@1"
let line_shares_kind = "core.line_shares@1"
let find_kind = "core.find@1"

let bare ~id ~kind ~box ~delivery =
  {
    id;
    kind;
    box;
    delivery;
    template = None;
    ink = None;
    color_range = None;
    test = [];
    find = None;
  }

let color_stats_probe ~id ~box ~delivery =
  bare ~id ~kind:color_stats_kind ~box ~delivery

let template_match_probe ?ink ~id ~box ~delivery ~template () =
  {
    (bare ~id ~kind:template_match_kind ~box ~delivery) with
    template = Some template;
    ink;
  }

let color_count_probe ~id ~box ~delivery ~min ~max =
  {
    (bare ~id ~kind:color_count_kind ~box ~delivery) with
    color_range = Some { min; max };
  }

let line_shares_probe ~id ~box ~delivery ~test =
  if test = [] then Error ("core.line_shares@1 needs a comparison: " ^ id)
  else Ok { (bare ~id ~kind:line_shares_kind ~box ~delivery) with test }

let find_probe ?template ~id ~box ~delivery params =
  {
    (bare ~id ~kind:find_kind ~box ~delivery) with
    template;
    find = Some params;
  }

let channels_of_json what j =
  match List.map (to_int what) (to_list what j) with
  | [ r; g; b ] -> (r, g, b)
  | _ -> fail "%s: expected [r, g, b]" what

let json_of_channels (r, g, b) = `List [ `Int r; `Int g; `Int b ]

(* [what] is the object holding [min] and [max]: the probe, or its ink. *)
let color_range_of_json what j =
  match (field_opt what "min" j, field_opt what "max" j) with
  | None, None -> None
  | Some min, Some max ->
      Some
        {
          min = channels_of_json (what ^ ".min") min;
          max = channels_of_json (what ^ ".max") max;
        }
  | _ -> fail "%s: min and max come together" what

let color_range_fields { min; max } =
  [ ("min", json_of_channels min); ("max", json_of_channels max) ]

let json_of_color_range = function
  | Some range -> color_range_fields range
  | None -> []

let ink_of_json j =
  match field_opt "probe" "ink" j with
  | None -> None
  | Some ink -> (
      match color_range_of_json "probe.ink" ink with
      | Some range -> Some range
      | None -> fail "probe.ink: needs min and max")

let json_of_ink = function
  | Some range -> [ ("ink", `Assoc (color_range_fields range)) ]
  | None -> []

let test_of_json j =
  match field_opt "probe" "test" j with
  | Some test -> Line_shares.test_of_json "probe.test" test
  | None -> []

let find_of_json kind j =
  if kind = find_kind then Some (Blob_find.params_of_json "probe" j) else None

let probe_spec_of_json j =
  let what = "probe" in
  let kind = string_field what "kind" j in
  {
    id = string_field what "id" j;
    kind;
    box = box_of_json (field what "box" j);
    delivery = delivery_of_string (string_field what "delivery" j);
    template =
      Option.map (to_string "probe.template") (field_opt what "template" j);
    ink = ink_of_json j;
    color_range = color_range_of_json what j;
    test = test_of_json j;
    find = find_of_json kind j;
  }

let json_of_template = function
  | Some t -> [ ("template", `String t) ]
  | None -> []

let json_of_test = function
  | [] -> []
  | test -> [ ("test", Line_shares.json_of_test test) ]

let json_of_find = function
  | Some params -> Blob_find.params_fields params
  | None -> []

let json_of_probe_spec p =
  `Assoc
    ([
       ("id", `String p.id);
       ("kind", `String p.kind);
       ("box", json_of_box p.box);
       ("delivery", `String (string_of_delivery p.delivery));
     ]
    @ json_of_template p.template
    @ json_of_ink p.ink
    @ json_of_color_range p.color_range
    @ json_of_test p.test @ json_of_find p.find)

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
  | Color_count of { fraction : float; mean : rgb option }
  | Line_shares of Line_shares.t
  | Find of { blobs : Blob_find.blob list }
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

let color_count_of_json what j =
  Color_count
    {
      fraction = float_field what "fraction" j;
      mean =
        (match field what "mean" j with
        | `Null -> None
        | mean -> Some (rgb_of_json "probe.mean" mean));
    }

let probe_result_of_json j =
  let what = "probe result" in
  match string_field what "kind" j with
  | kind when kind = color_stats_kind -> color_stats_of_json what j
  | kind when kind = template_match_kind -> template_match_of_json what j
  | kind when kind = color_count_kind -> color_count_of_json what j
  | kind when kind = line_shares_kind ->
      Line_shares (Line_shares.of_json what j)
  | kind when kind = find_kind -> Find { blobs = Blob_find.of_json what j }
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

let json_of_color_count ~fraction ~mean =
  `Assoc
    [
      ("kind", `String color_count_kind);
      ("fraction", `Float fraction);
      ("mean", Option.fold ~none:`Null ~some:json_of_rgb mean);
    ]

let json_of_probe_result = function
  | Color_stats { mean; stddev } -> json_of_color_stats ~mean ~stddev
  | Template_match { score; x; y } -> json_of_template_match ~score ~x ~y
  | Color_count { fraction; mean } -> json_of_color_count ~fraction ~mean
  | Line_shares shares -> Line_shares.to_json shares
  | Find { blobs } -> Blob_find.to_json blobs
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

let unsubscribe_result_of_json j =
  string_list_field "unsubscribe.result" "unsubscribed" j

let json_of_unsubscribe_result ids =
  `Assoc [ ("unsubscribed", json_of_strings ids) ]
