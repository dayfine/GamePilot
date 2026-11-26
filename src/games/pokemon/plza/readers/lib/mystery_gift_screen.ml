let header_id = "mystery_gift.card_header"
let text_box_id = "mystery_gift.text_box"
let items = 6

let header : Native_box.fractions =
  { left = 0.30; top = 0.26; width = 0.40; height = 0.05 }

let text_box : Native_box.fractions =
  { left = 0.26; top = 0.80; width = 0.48; height = 0.12 }

(* Item k's right end (past its name, short of its red dot) and its name's
   window, in frame pixels: items 84 apart. *)
let item_pitch = 84
let item_strip_y = 310
let name_window_y = 554

let item_strip k : Native_box.t =
  { x = 1010; y = item_strip_y + (item_pitch * k); w = 310; h = 40 }

let name_window k : Native_box.t =
  { x = 576; y = name_window_y + (item_pitch * (k - 3)); w = 436; h = 62 }

let item_id k = Printf.sprintf "mystery_gift.item%d" k
let name_id k = Printf.sprintf "mystery_gift.name%d" k

(* White from 200: the card's header and the selected item are 253 on
   console B, and a dimmer capture card keeps them (0.9 times is 228). Dark
   blue: red under 45, green under 70, blue 66 to 144. *)
let white_min = 200
let white = Color_count.white white_min
let blue_red_max = 44
let blue_green_max = 69
let blue_min = 66
let blue_max = 144

let blue : Color_count.range =
  { low = (0, 0, blue_min); high = (blue_red_max, blue_green_max, blue_max) }

let name_probe ~picture ~gift_name k =
  Option.map
    (fun box ->
      Wire.template_match_probe ~id:(name_id k) ~box ~delivery:Every
        ~template:gift_name ())
    (Native_box.probe_box ~picture (name_window k))

let all = List.init items Fun.id

let probes ~picture ~gift_name =
  Color_count.probe ~picture ~id:header_id
    (Native_box.of_fractions header)
    white
  @ Color_count.probe ~picture ~id:text_box_id
      (Native_box.of_fractions text_box)
      blue
  @ List.concat_map
      (fun k -> Color_count.probe ~picture ~id:(item_id k) (item_strip k) white)
      all
  @ List.filter_map Fun.id
      (Option.fold ~none:[]
         ~some:(fun gift_name -> List.map (name_probe ~picture ~gift_name) all)
         gift_name)

let fraction = Color_count.share

let score m id =
  match Effects.probe m id with
  | Some (Wire.Template_match { score; _ }) -> Some score
  | Some
      ( Wire.Color_stats _ | Wire.Color_count _ | Wire.Line_shares _
      | Wire.Find _ | Wire.Other _ )
  | None ->
      None

let min_white = 0.70
let max_other_white = 0.30
let max_list_blue = 0.50
let min_card_blue = 0.60
let max_name_score = 0.05
let holds m id test = Option.fold ~none:false ~some:test (fraction m id)
let white_item m k = holds m (item_id k) (fun s -> s > min_white)
let dim_item m k = holds m (item_id k) (fun s -> s < max_other_white)

let selected_item m =
  match List.filter (white_item m) all with
  | [ k ] when List.for_all (fun j -> j = k || dim_item m j) all -> Some k
  | _ -> None

let list_active m =
  selected_item m <> None && holds m text_box_id (fun s -> s < max_list_blue)

(* The card covers the list's first item but for part of its strip; the
   list under a question with its cursor there reads as white on the header
   and as blue on the box. *)
let card m =
  holds m header_id (fun s -> s > min_white)
  && holds m text_box_id (fun s -> s > min_card_blue)
  && not (white_item m 0)

let name_scores m = List.map (fun k -> score m (name_id k)) all

let best (best_k, best_s) (k, s) =
  match s with Some s when s < best_s -> (Some k, s) | _ -> (best_k, best_s)

let gift_item m =
  let k, s =
    List.fold_left best (None, Float.infinity)
      (List.mapi (fun k s -> (k, s)) (name_scores m))
  in
  if s <= max_name_score then k else None

let share m id =
  Option.fold ~none:"-" ~some:(Printf.sprintf "%.2f") (fraction m id)

let describe m =
  let names =
    List.map
      (Option.fold ~none:"-" ~some:(Printf.sprintf "%.3f"))
      (name_scores m)
  in
  Printf.sprintf "items white %s; names %s; card header %s, text box %s"
    (String.concat " " (List.map (fun k -> share m (item_id k)) all))
    (String.concat " " names) (share m header_id) (share m text_box_id)
