type white_part = Box_and_arrow | Box_only

let white_edge_id = "dialog_box.white_edge"
let black_arrow_id = "dialog_box.black_arrow"
let blue_corner_id = "dialog_box.blue_corner"
let white_arrow_id = "dialog_box.white_arrow"
let teal_arrow_id = "dialog_box.teal_arrow"

(* The white box's bottom edge, the blue box's corner and the arrows' box, as
   fractions of the frame. *)
let white_edge =
  Native_box.of_fractions
    { left = 0.265; top = 0.931; width = 0.465; height = 0.020 }

let blue_corner =
  Native_box.of_fractions
    { left = 0.765093; top = 0.933594; width = 0.006586; height = 0.013672 }

let arrow_box =
  Native_box.of_fractions
    { left = 0.727; top = 0.868; width = 0.037; height = 0.086 }

let white_min_sum = 500.
let white_max_stddev_sum = 20.

(* The blue box's two blues, as channel shares, within 0.25 (stddevs summing
   to 10 at most). *)
let blues : Wire.rgb list =
  [
    { r = 0.0869318; g = 0.255479; b = 0.65759 };
    { r = 0.; g = 0.134207; b = 0.865793 };
  ]

let blue_max_distance = 0.25
let blue_max_stddev_sum = 10.
let arrow_min_area = 150.
let arrow_max_score = 120.

(* Each crop's size and fill as templates.json gives them, with the bounds
   the fork allows each arrow. *)
let black_arrow : Blob_template.t =
  {
    width = 32;
    height = 19;
    fill = 0.358553;
    aspect_lower = 0.9;
    aspect_upper = 1.2;
    fill_lower = 0.83;
    fill_upper = 1.1;
  }

let white_arrow : Blob_template.t =
  {
    width = 32;
    height = 19;
    fill = 0.373355;
    aspect_lower = 0.9;
    aspect_upper = 1.1;
    fill_lower = 0.85;
    fill_upper = 1.1;
  }

let teal_arrow : Blob_template.t =
  {
    width = 31;
    height = 19;
    fill = 0.365025;
    aspect_lower = 0.9;
    aspect_upper = 1.1;
    fill_lower = 0.8;
    fill_upper = 1.1;
  }

let black_arrow_ranges =
  List.map Find_probe.filter
    Find_probe.
      [
        { min = 0xff000000; max = 0xff646464 };
        { min = 0xff000000; max = 0xff828282 };
      ]

let white_arrow_ranges =
  List.map Find_probe.filter
    Find_probe.
      [
        { min = 0xffc0c0c0; max = 0xffffffff };
        { min = 0xffb0b0b0; max = 0xffffffff };
        { min = 0xffa0a0a0; max = 0xffffffff };
        { min = 0xff909090; max = 0xffffffff };
        { min = 0xff808080; max = 0xffffffff };
      ]

let teal_arrow_ranges =
  [ Find_probe.(filter { min = 0xff00c080; max = 0xff3fffff }) ]

let arrow_probe ~picture ~id ~template filters =
  Find_probe.probe ~template ~picture ~id arrow_box
    (Wire.Blob_find.params ~filters ~min_area:arrow_min_area ())

let probes ~picture ~(assets : Blob_assets.t) =
  List.concat
    [
      Box_color.probe ~picture ~id:white_edge_id white_edge;
      arrow_probe ~picture ~id:black_arrow_id
        ~template:assets.dialog_black_arrow black_arrow_ranges;
      Box_color.probe ~picture ~id:blue_corner_id blue_corner;
      arrow_probe ~picture ~id:white_arrow_id
        ~template:assets.dialog_white_arrow white_arrow_ranges;
      arrow_probe ~picture ~id:teal_arrow_id ~template:assets.dialog_teal_arrow
        teal_arrow_ranges;
    ]

let arrow_found m id template =
  List.exists
    (Blob_template.matches template ~max_score:arrow_max_score)
    (Find_probe.read m id)

let white_box m =
  match Box_color.read m white_edge_id with
  | Some s ->
      Box_color.is_white ~min_sum:white_min_sum
        ~max_stddev_sum:white_max_stddev_sum s
  | None -> false

let blue_box m =
  let blue s ratio =
    Box_color.is_solid ~ratio ~max_distance:blue_max_distance
      ~max_stddev_sum:blue_max_stddev_sum s
  in
  match Box_color.read m blue_corner_id with
  | Some s ->
      List.exists (blue s) blues && arrow_found m white_arrow_id white_arrow
  | None -> false

let shown ~white m =
  let white_shown =
    match white with
    | Box_only -> white_box m
    | Box_and_arrow -> white_box m && arrow_found m black_arrow_id black_arrow
  in
  white_shown || blue_box m || arrow_found m teal_arrow_id teal_arrow
