let top_bar_id = "mystery_gift.top_bar"
let header_id = "mystery_gift.card_header"
let text_box_id = "mystery_gift.text_box"

let top_bar : Native_box.fractions =
  { left = 0.32; top = 0.28; width = 0.36; height = 0.05 }

let header : Native_box.fractions =
  { left = 0.30; top = 0.26; width = 0.40; height = 0.05 }

let text_box : Native_box.fractions =
  { left = 0.26; top = 0.80; width = 0.48; height = 0.12 }

(* Inclusive ranges for the script's strict tests: white over 230; dark blue
   red under 45, green under 70, blue 66 to 144. *)
let white_min = 231
let channel_max = 255

let white =
  ((white_min, white_min, white_min), (channel_max, channel_max, channel_max))

let blue_red_max = 44
let blue_green_max = 69
let blue_min = 66
let blue_max = 144
let blue = ((0, 0, blue_min), (blue_red_max, blue_green_max, blue_max))

let count ~picture id box (min, max) =
  Option.map
    (fun box -> Wire.color_count_probe ~id ~box ~delivery:Every ~min ~max)
    (Native_box.probe_box ~picture (Native_box.of_fractions box))

let probes ~picture =
  List.filter_map Fun.id
    [
      count ~picture top_bar_id top_bar white;
      count ~picture header_id header white;
      count ~picture text_box_id text_box blue;
    ]

let fraction m id =
  match Effects.probe m id with
  | Some (Wire.Color_count { fraction; _ }) -> Some fraction
  | Some
      ( Wire.Color_stats _ | Wire.Template_match _ | Wire.Line_shares _
      | Wire.Find _ | Wire.Other _ )
  | None ->
      None

let min_white = 0.70
let max_list_blue = 0.50
let min_card_blue = 0.60
let holds m id test = Option.fold ~none:false ~some:test (fraction m id)

let list_active m =
  holds m top_bar_id (fun s -> s > min_white)
  && holds m text_box_id (fun s -> s < max_list_blue)

let card m =
  holds m header_id (fun s -> s > min_white)
  && holds m text_box_id (fun s -> s > min_card_blue)

let describe m =
  let f id =
    Option.fold ~none:"-" ~some:(Printf.sprintf "%.2f") (fraction m id)
  in
  Printf.sprintf "top bar %s, card header %s, text box %s" (f top_bar_id)
    (f header_id) (f text_box_id)
