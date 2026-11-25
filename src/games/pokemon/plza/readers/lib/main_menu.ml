let right_id = "main_menu_right"
let b_id = "main_menu_b"

let right_area =
  Native_box.of_fractions
    { left = 0.382; top = 0.081; width = 0.029; height = 0.056 }

let b_area =
  Native_box.of_fractions
    { left = 0.87; top = 0.940; width = 0.077; height = 0.044 }

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

(* The fork's least area (1000 at 4K) and sides (50 at 4K), scaled to
   1080p. *)
let min_area = 250.
let min_side = 25.
let right_max_score = 70.
let b_max_score = 80.

(* The crops' sizes and fills as templates.json gives them, with the
   WaterfillTemplateMatcher's default bounds. *)
let template ~fill : Blob_template.t =
  {
    width = 30;
    height = 30;
    fill;
    aspect_lower = 0.8;
    aspect_upper = 1.25;
    fill_lower = 0.8;
    fill_upper = 1.25;
  }

let right_fill = 0.69
let b_fill = 0.605556
let button_right = template ~fill:right_fill
let button_b = template ~fill:b_fill

let params =
  Wire.Blob_find.params ~filters:bright ~min_area ~min_size:(min_side, min_side)
    ()

let probes ~picture ~(assets : Blob_assets.t) =
  Find_probe.probe ~template:assets.button_right ~picture ~id:right_id
    right_area params
  @ Find_probe.probe ~template:assets.button_b ~picture ~id:b_id b_area params

let found m id t ~max_score =
  List.exists (Blob_template.matches t ~max_score) (Find_probe.read m id)

let buttons m =
  ( found m right_id button_right ~max_score:right_max_score,
    found m b_id button_b ~max_score:b_max_score )

let shown m =
  let right, b = buttons m in
  right && b
