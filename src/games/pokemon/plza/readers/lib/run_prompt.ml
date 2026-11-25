let id = "run_prompt"

let area =
  Native_box.of_fractions
    { left = 0.004456; top = 0.635499; width = 0.065062; height = 0.077655 }

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

(* The fork's least area (1000 at 4K) and sides (30 at 4K), scaled to 1080p,
   as for the party bar's D-pad markers. *)
let min_area = 250.
let min_side = 15.
let max_score = 80.

(* The crop's size and fill as templates.json gives them, with the
   WaterfillTemplateMatcher's default bounds. *)
let button_minus : Blob_template.t =
  {
    width = 30;
    height = 30;
    fill = 0.742222;
    aspect_lower = 0.8;
    aspect_upper = 1.25;
    fill_lower = 0.8;
    fill_upper = 1.25;
  }

let probes ~picture ~(assets : Blob_assets.t) =
  Find_probe.probe ~template:assets.button_minus ~picture ~id area
    (Wire.Blob_find.params ~filters:bright ~min_area
       ~min_size:(min_side, min_side) ())

let shown m =
  List.exists
    (Blob_template.matches button_minus ~max_score)
    (Find_probe.read m id)
