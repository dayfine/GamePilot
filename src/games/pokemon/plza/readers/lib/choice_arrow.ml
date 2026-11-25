let id = "choice_arrow"

(* From x 960 (our own left edge) to the fork's box's right edge. *)
let left_px = 960
let right = 0.949837
let left = float_of_int left_px /. float_of_int Native_box.frame_width

let area =
  Native_box.of_fractions
    { left; top = 0.481553; width = right -. left; height = 0.312621 }

let ranges =
  List.map Find_probe.filter
    Find_probe.
      [
        { min = 0xff808000; max = 0xffffff7f };
        { min = 0xff808000; max = 0xffdfff7f };
        { min = 0xff80a000; max = 0xffffff7f };
        { min = 0xff80a000; max = 0xffdfff7f };
        { min = 0xff80c000; max = 0xffffff7f };
        { min = 0xff80c000; max = 0xffdfff7f };
      ]

let min_area = 700.
let max_score = 80.

(* The crop's size and fill as templates.json gives them, with the bounds the
   fork allows the arrow. *)
let arrow : Blob_template.t =
  {
    width = 41;
    height = 57;
    fill = 0.384681;
    aspect_lower = 0.9;
    aspect_upper = 1.1;
    fill_lower = 0.85;
    fill_upper = 1.1;
  }

let probes ~picture ~(assets : Blob_assets.t) =
  Find_probe.probe ~template:assets.choice_arrow ~picture ~id area
    (Wire.Blob_find.params ~filters:ranges ~min_area ())

let shown m =
  List.exists (Blob_template.matches arrow ~max_score) (Find_probe.read m id)
