module PB = Switch.Picture_box

let munchlax_template_asset =
  "third_party/Packages/Resources/PokemonBDSP/Rng/Munchlax.png"

let munchlax_probe_id = "bdsp_eye_munchlax"
let munchlax_box : Wire.box = { x = 0.3828; y = 0.6306; w = 0.0208; h = 0.0481 }

type target = { id : string; box : Wire.box; template : Effects.template_hash }

let munchlax_target ~template =
  { id = munchlax_probe_id; box = munchlax_box; template }

let probe_of_target ~picture t =
  Option.map
    (fun box ->
      Wire.template_ncc_probe ~id:t.id ~box ~delivery:Every ~template:t.template)
    (PB.clipped ~picture t.box)

let probes ~picture targets = List.filter_map (probe_of_target ~picture) targets

let score frame id =
  match Effects.probe frame id with
  | Some (Wire.Template_ncc { score; _ }) -> Some score
  | _ -> None

let dip_depth ~resting value =
  if resting <= 0.0 then 0.0
  else Float.max 0.0 (Float.min 1.0 ((resting -. value) /. resting))

let is_blink_dip ~resting ~threshold value =
  resting > 0.0 && threshold > 0.0 && dip_depth ~resting value > threshold
