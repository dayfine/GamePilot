let tab_id = "boxes_screen.tab"
let party_id = "boxes_screen.party_title"
let tab : Native_box.t = { x = 130; y = 30; w = 110; h = 36 }
let party_title : Native_box.t = { x = 100; y = 100; w = 240; h = 40 }
let white_min = 200
let channel_max = 255

let white ~picture id box =
  Option.map
    (fun box ->
      Wire.color_count_probe ~id ~box ~delivery:Every
        ~min:(white_min, white_min, white_min)
        ~max:(channel_max, channel_max, channel_max))
    (Native_box.probe_box ~picture box)

let probes ~picture =
  List.filter_map Fun.id
    [ white ~picture tab_id tab; white ~picture party_id party_title ]

let fraction m id =
  match Effects.probe m id with
  | Some (Wire.Color_count { fraction; _ }) -> Some fraction
  | Some
      ( Wire.Color_stats _ | Wire.Template_match _ | Wire.Line_shares _
      | Wire.Find _ | Wire.Other _ )
  | None ->
      None

let min_tab = 0.80
let max_party = 0.05

let shown m =
  match (fraction m tab_id, fraction m party_id) with
  | Some t, Some p -> t > min_tab && p < max_party
  | _ -> false
