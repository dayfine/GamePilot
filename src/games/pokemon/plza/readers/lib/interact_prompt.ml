let id = "interact_prompt"

let area =
  Native_box.of_fractions { left = 0.3; top = 0.2; width = 0.4; height = 0.65 }

let ranges =
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

let min_area = 250.
let min_side = 25.
let max_score = 70.

(* The crop's size and fill as templates.json gives them, with the
   WaterfillTemplateMatcher's default bounds. *)
let button_a : Blob_template.t =
  {
    width = 34;
    height = 33;
    fill = 0.650624;
    aspect_lower = 0.8;
    aspect_upper = 1.25;
    fill_lower = 0.8;
    fill_upper = 1.25;
  }

let probes_over ~picture ~(assets : Blob_assets.t) ~id area =
  Find_probe.probe ~template:assets.button_a ~picture ~id area
    (Wire.Blob_find.params ~filters:ranges ~min_area
       ~min_size:(min_side, min_side) ())

let shown_over m id =
  List.exists (Blob_template.matches button_a ~max_score) (Find_probe.read m id)

let probes ~picture ~assets = probes_over ~picture ~assets ~id area
let shown m = shown_over m id
