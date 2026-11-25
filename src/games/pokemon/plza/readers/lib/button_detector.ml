type button =
  | A
  | B
  | Minus
  | Right
  | Dpad_up
  | Dpad_down
  | Dpad_up_interior
  | Dpad_down_interior

let bright =
  List.map Find_probe.filter
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
  List.map Find_probe.filter
    Find_probe.
      [
        { min = 0xff000000; max = 0xff404040 };
        { min = 0xff000000; max = 0xff505050 };
        { min = 0xff000000; max = 0xff606060 };
        { min = 0xff000000; max = 0xff707070 };
      ]

(* 4K lengths and areas at 1080p. *)
let side_scale = 0.5
let area_scale = 0.25
let min_area_4k = 1000.
let interior_min_area_4k = 100.

(* One button's matcher, as the fork's ButtonMatcher table gives it: the least
   side at 4K and the score limit, with the crop's size and fill as
   templates.json gives them. *)
type matcher = {
  template : Blob_assets.t -> string;
  interior : bool;
  min_side_4k : float;
  max_score : float;
  width : int;
  height : int;
  fill : float;
}

let button_a =
  {
    template = (fun a -> a.button_a);
    interior = false;
    min_side_4k = 50.;
    max_score = 70.;
    width = 34;
    height = 33;
    fill = 0.650624;
  }

let button_b =
  {
    template = (fun a -> a.button_b);
    interior = false;
    min_side_4k = 50.;
    max_score = 80.;
    width = 30;
    height = 30;
    fill = 0.605556;
  }

let button_minus =
  {
    template = (fun a -> a.button_minus);
    interior = false;
    min_side_4k = 30.;
    max_score = 80.;
    width = 30;
    height = 30;
    fill = 0.742222;
  }

let button_right =
  {
    template = (fun a -> a.button_right);
    interior = false;
    min_side_4k = 50.;
    max_score = 70.;
    width = 30;
    height = 30;
    fill = 0.69;
  }

let dpad_up =
  {
    template = (fun a -> a.button_dpad_up);
    interior = false;
    min_side_4k = 30.;
    max_score = 80.;
    width = 30;
    height = 30;
    fill = 0.631111;
  }

let dpad_down =
  {
    template = (fun a -> a.button_dpad_down);
    interior = false;
    min_side_4k = 30.;
    max_score = 80.;
    width = 30;
    height = 30;
    fill = 0.633333;
  }

let interior template =
  {
    template;
    interior = true;
    min_side_4k = 10.;
    max_score = 120.;
    width = 12;
    height = 10;
    fill = 0.583333;
  }

let matcher = function
  | A -> button_a
  | B -> button_b
  | Minus -> button_minus
  | Right -> button_right
  | Dpad_up -> dpad_up
  | Dpad_down -> dpad_down
  | Dpad_up_interior -> interior (fun a -> a.button_dpad_up_interior)
  | Dpad_down_interior -> interior (fun a -> a.button_dpad_down_interior)

(* The default bounds of CommonTools/ImageMatch/WaterfillTemplateMatcher.cpp. *)
let shape m : Blob_template.t =
  {
    width = m.width;
    height = m.height;
    fill = m.fill;
    aspect_lower = 0.8;
    aspect_upper = 1.25;
    fill_lower = 0.8;
    fill_upper = 1.25;
  }

let params m =
  let filters, area_4k =
    if m.interior then (dark, interior_min_area_4k) else (bright, min_area_4k)
  in
  let side = m.min_side_4k *. side_scale in
  Wire.Blob_find.params ~filters ~min_area:(area_4k *. area_scale)
    ~min_size:(side, side) ()

let probe ~picture ~assets ~id button box =
  let m = matcher button in
  Find_probe.probe ~template:(m.template assets) ~picture ~id box (params m)

let shown measurements id button =
  let m = matcher button in
  List.exists
    (Blob_template.matches (shape m) ~max_score:m.max_score)
    (Find_probe.read measurements id)
