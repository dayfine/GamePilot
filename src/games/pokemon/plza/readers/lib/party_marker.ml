let slots = 6

(* Each slot's box on the frame: under its icon, where the marker shows. *)
let first_left = 0.048
let slot_pitch = 0.0398

let slot_box i =
  Native_box.of_fractions
    {
      left = first_left +. (slot_pitch *. float_of_int i);
      top = 0.926;
      width = 0.017;
      height = 0.058;
    }

type marker = {
  name : string;
  template : Blob_assets.t -> string;
  shape : Blob_template.t;
  ranges : Find_probe.argb_range list;
  min_area : float;
  min_side : float;
  max_score : float;
}

let bright =
  Find_probe.
    [
      { min = 0xff808080; max = 0xffffffff };
      { min = 0xff909090; max = 0xffffffff };
      { min = 0xffa0a0a0; max = 0xffffffff };
      { min = 0xffb0b0b0; max = 0xffffffff };
      { min = 0xffc0c0c0; max = 0xffffffff };
      { min = 0xffd0d0d0; max = 0xffffffff };
      { min = 0xffe0e0e0; max = 0xffffffff };
      { min = 0xfff0f0f0; max = 0xffffffff };
    ]

let dark =
  Find_probe.
    [
      { min = 0xff000000; max = 0xff404040 };
      { min = 0xff000000; max = 0xff505050 };
      { min = 0xff000000; max = 0xff606060 };
      { min = 0xff000000; max = 0xff707070 };
    ]

(* The crops' sizes and fills as templates.json gives them, with the
   WaterfillTemplateMatcher's default bounds. *)
let button_side = 30
let interior_width = 12
let interior_height = 10
let interior_fill = 0.583333
let up_fill = 0.631111
let down_fill = 0.633333

let shape ~width ~height ~fill : Blob_template.t =
  {
    width;
    height;
    fill;
    aspect_lower = 0.8;
    aspect_upper = 1.25;
    fill_lower = 0.8;
    fill_upper = 1.25;
  }

(* The fork's least areas (1000 and 100 at 4K) and sides (30 and 10 at 4K),
   scaled to 1080p. *)
let button name template ~fill =
  {
    name;
    template;
    shape = shape ~width:button_side ~height:button_side ~fill;
    ranges = bright;
    min_area = 250.;
    min_side = 15.;
    max_score = 80.;
  }

let interior name template =
  {
    name;
    template;
    shape =
      shape ~width:interior_width ~height:interior_height ~fill:interior_fill;
    ranges = dark;
    min_area = 25.;
    min_side = 5.;
    max_score = 120.;
  }

let markers =
  [
    button "up" (fun a -> a.button_dpad_up) ~fill:up_fill;
    button "down" (fun a -> a.button_dpad_down) ~fill:down_fill;
    interior "up_interior" (fun a -> a.button_dpad_up_interior);
    interior "down_interior" (fun a -> a.button_dpad_down_interior);
  ]

let id marker i = Printf.sprintf "party_marker.%s.%d" marker.name i

let marker_probes ~picture ~assets marker i =
  Find_probe.probe ~template:(marker.template assets) ~picture ~id:(id marker i)
    (slot_box i)
    (Wire.Blob_find.params
       ~filters:(List.map Find_probe.filter marker.ranges)
       ~min_area:marker.min_area
       ~min_size:(marker.min_side, marker.min_side)
       ())

let probes ~picture ~assets =
  List.concat_map
    (fun marker ->
      List.concat (List.init slots (marker_probes ~picture ~assets marker)))
    markers

let in_slot m marker i =
  List.exists
    (Blob_template.matches marker.shape ~max_score:marker.max_score)
    (Find_probe.read m (id marker i))

let slot_shows m i = List.exists (fun marker -> in_slot m marker i) markers
let shown m = List.exists (slot_shows m) (List.init slots Fun.id)

let down_markers =
  List.filter (fun m -> m.name = "down" || m.name = "down_interior") markers

let down_slot m =
  List.find_opt
    (fun i -> List.exists (fun marker -> in_slot m marker i) down_markers)
    (List.init slots Fun.id)
