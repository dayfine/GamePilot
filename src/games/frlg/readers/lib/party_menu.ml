type mark = No_mark | Held_item | Mail

let mark_name = function
  | No_mark -> "none"
  | Held_item -> "held"
  | Mail -> "mail"

let slots = 6
let dialog_id = "party.dialog"
let background_id = "party.background"
let selected_id n = Printf.sprintf "party.selected%d" n
let empty_id n = Printf.sprintf "party.empty%d" n
let red_id n = Printf.sprintf "party.item_red%d" n
let yellow_id n = Printf.sprintf "party.item_yellow%d" n
let mail_id n = Printf.sprintf "party.mail%d" n

(* (5, 108, 105) teal; the border's orange FF701C. *)
let teal : Wire.rgb = { r = 0.020; g = 0.424; b = 0.412 }
let orange : Wire.rgb = { r = 0.6455696; g = 0.2835; b = 0.070886 }
let max_distance = 0.25
let max_teal_stddev_sum = 20.
let max_border_stddev_sum = 30.

(* PartySlotDetector::party_slot_boxes: the border's left edge for slot 1,
   the right edge for the others. *)
let selected_boxes : Wire.box list =
  [
    { x = 0.035000; y = 0.376617; w = 0.003280; h = 0.070000 };
    { x = 0.985000; y = 0.080000; w = 0.003280; h = 0.099663 };
    { x = 0.985000; y = 0.230000; w = 0.003280; h = 0.099663 };
    { x = 0.985000; y = 0.380000; w = 0.003280; h = 0.099663 };
    { x = 0.985000; y = 0.530000; w = 0.003280; h = 0.099663 };
    { x = 0.985000; y = 0.675000; w = 0.003280; h = 0.099663 };
  ]

(* PartyEmptySlotDetector::box_for_slot, slots 2 to 6. *)
let empty_boxes : Wire.box list =
  [
    { x = 0.709; y = 0.078; w = 0.01; h = 0.018 };
    { x = 0.709; y = 0.228; w = 0.01; h = 0.018 };
    { x = 0.709; y = 0.378; w = 0.01; h = 0.018 };
    { x = 0.709; y = 0.527; w = 0.01; h = 0.018 };
    { x = 0.709; y = 0.677; w = 0.01; h = 0.018 };
  ]

(* The icon at the sprite's bottom right, measured on mGBA: slot 1's at x
   19-24, y 49-54; the right column's at x 107-112, from 3 below each row's
   top (rows 24 apart from y 24). The fork's boxes cover only part of it. *)
let row_step = 24.

let mark_box n =
  if n = 1 then Game_pixels.box { x = 16.; y = 46.; w = 10.; h = 10. }
  else
    Game_pixels.box
      { x = 104.; y = row_step *. float_of_int (n - 1); w = 10.; h = 10. }

(* The fork's ranges for the item icon; the mail's lavender measured. *)
let item_red : Color_count.range =
  { low = { r = 200; g = 60; b = 30 }; high = { r = 255; g = 160; b = 140 } }

let item_yellow : Color_count.range =
  { low = { r = 210; g = 210; b = 100 }; high = { r = 255; g = 255; b = 190 } }

let mail_lavender : Color_count.range =
  { low = { r = 200; g = 200; b = 240 }; high = { r = 240; g = 240; b = 255 } }

let max_filled_stddev_sum = 20.
let min_item_red = 0.01
let min_item_yellow = 0.15
let min_mail_lavender = 0.04

let slot_probes n =
  let box = mark_box n in
  [
    Solid_color.probe ~id:(selected_id n) (List.nth selected_boxes (n - 1));
    Color_count.probe ~id:(red_id n) box item_red;
    Color_count.probe ~id:(yellow_id n) box item_yellow;
    Color_count.probe ~id:(mail_id n) box mail_lavender;
  ]
  @
  if n = 1 then []
  else [ Solid_color.probe ~id:(empty_id n) (List.nth empty_boxes (n - 2)) ]

let all_slots = List.init slots (fun i -> i + 1)

let probes =
  Solid_color.probe ~id:dialog_id { x = 0.028; y = 0.840; w = 0.705; h = 0.010 }
  :: Solid_color.probe ~id:background_id
       { x = 0.028; y = 0.500; w = 0.010; h = 0.250 }
  :: List.concat_map slot_probes all_slots

let party_menu m =
  Solid_color.holds m dialog_id (fun s -> Solid_color.is_white s)
  && Solid_color.holds m background_id
       (Solid_color.is_solid ~ratio:teal ~max_distance
          ~max_stddev_sum:max_teal_stddev_sum)

let selected_slot m =
  let orange_border n =
    Solid_color.holds m (selected_id n)
      (Solid_color.is_solid ~ratio:orange ~max_distance
         ~max_stddev_sum:max_border_stddev_sum)
  in
  match List.filter orange_border all_slots with [ n ] -> Some n | _ -> None

let slot_empty m n =
  n > 1
  && Solid_color.holds m (empty_id n) (fun s ->
         Solid_color.sum s.stddev > max_filled_stddev_sum)

let members m =
  match List.find_opt (slot_empty m) all_slots with
  | Some n -> n - 1
  | None -> slots

let share m id = Option.value (Color_count.share m id) ~default:0.

let mark m n =
  if
    share m (red_id n) >= min_item_red
    && share m (yellow_id n) >= min_item_yellow
  then Held_item
  else if share m (mail_id n) >= min_mail_lavender then Mail
  else No_mark
