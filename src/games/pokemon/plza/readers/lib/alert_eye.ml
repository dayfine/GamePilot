let ids = [ "alert_eye.bar"; "alert_eye.initial" ]

(* The eye on the alert bar, and the bigger one as the bar first shows. *)
let areas =
  [
    Native_box.of_fractions
      { left = 0.485; top = 0.088; width = 0.029; height = 0.034 };
    Native_box.of_fractions
      { left = 0.464; top = 0.142; width = 0.071; height = 0.074 };
  ]

let ranges =
  List.map Find_probe.filter
    Find_probe.
      [
        { min = 0xff808080; max = 0xffffffff };
        { min = 0xff909090; max = 0xffffffff };
        { min = 0xffa0a0a0; max = 0xffffffff };
        { min = 0xffb0b0b0; max = 0xffffffff };
        { min = 0xffc0c0c0; max = 0xffffffff };
      ]

let min_area = 300.

(* No least size in the fork: one pixel. *)
let min_side = 1.
let max_score = 60.

(* The crop's size and fill as templates.json gives them, with the
   bounds of the eye's matcher in PokemonLZA_AlertEyeDetector.cpp. *)
let eye : Blob_template.t =
  {
    width = 40;
    height = 26;
    fill = 0.504808;
    aspect_lower = 0.5;
    aspect_upper = 1.1;
    fill_lower = 0.75;
    fill_upper = 1.1;
  }

let params =
  Wire.Blob_find.params ~filters:ranges ~min_area ~min_size:(min_side, min_side)
    ()

let probe ~picture ~(assets : Blob_assets.t) id area =
  Find_probe.probe ~template:assets.alert_eye ~picture ~id area params

let probes ~picture ~assets =
  List.concat (List.map2 (probe ~picture ~assets) ids areas)

let shown m =
  List.exists
    (fun id ->
      List.exists (Blob_template.matches eye ~max_score) (Find_probe.read m id))
    ids
