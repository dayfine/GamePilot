let level_up_ids = ("party.level_up.border_top", "party.level_up.border_right")
let level_up_inner = ("party.level_up.top", "party.level_up.right")
let plus_id = "party.level_up.plus"
let yes_no_ids = ("party.yes_no.border_top", "party.yes_no.border_right")
let yes_no_inner = ("party.yes_no.top", "party.yes_no.right")

(* PartyLevelUpDetector's boxes: the stats window's grey border along its top
   and right, its white inside along the same edges, and the column left of
   the numbers where page 1 prints "+". *)
let level_up_boxes : (string * Wire.box) list =
  [
    ( fst level_up_ids,
      { x = 0.619231; y = 0.023038; w = 0.362179; h = 0.001923 } );
    ( snd level_up_ids,
      { x = 0.982692; y = 0.025923; w = 0.001923; h = 0.597115 } );
    ( fst level_up_inner,
      { x = 0.626282; y = 0.042492; w = 0.341026; h = 0.006175 } );
    ( snd level_up_inner,
      { x = 0.967949; y = 0.050923; w = 0.003846; h = 0.550962 } );
    (plus_id, { x = 0.862663; y = 0.051852; w = 0.017788; h = 0.553560 });
  ]

(* PartyMoveLearnDetector's boxes: the YES/NO window's border and inside, the
   same tests. *)
let yes_no_boxes : (string * Wire.box) list =
  [
    (fst yes_no_ids, { x = 0.685096; y = 0.422836; w = 0.229327; h = 0.002163 });
    (snd yes_no_ids, { x = 0.916346; y = 0.426442; w = 0.001442; h = 0.245913 });
    ( fst yes_no_inner,
      { x = 0.699038; y = 0.445913; w = 0.200000; h = 0.006490 } );
    ( snd yes_no_inner,
      { x = 0.899519; y = 0.454567; w = 0.004327; h = 0.194712 } );
  ]

(* The page background left of the party's boxes, x 2-6 as Party_menu's
   edge, above the message box (from y 113): PartySelectionDetector's box
   (y 80-120) reaches into the message box's frame. *)
let background_id = "party.dialogs.background"
let background_box = Game_pixels.box { x = 2.; y = 72.; w = 4.; h = 36. }

let probes =
  List.map
    (fun (id, b) -> Solid_color.probe ~id b)
    (((background_id, background_box) :: level_up_boxes) @ yes_no_boxes)

(* The background's teal (5, 108, 105). *)
let teal : Wire.rgb = { r = 0.020; g = 0.424; b = 0.412 }
let max_teal_stddev_sum = 20.

(* The border's grey (120, 115, 140), as the fork's is_solid takes it. *)
let border_grey : Wire.rgb = { r = 0.320; g = 0.307; b = 0.373 }
let max_border_distance = 0.25
let max_border_stddev_sum = 20.

let grey m id =
  Solid_color.holds m id
    (Solid_color.is_solid ~ratio:border_grey ~max_distance:max_border_distance
       ~max_stddev_sum:max_border_stddev_sum)

let white m id = Solid_color.holds m id (fun s -> Solid_color.is_white s)

let window m (border_top, border_right) (inner_top, inner_right) =
  grey m border_top && grey m border_right && white m inner_top
  && white m inner_right

let level_up_box m = window m level_up_ids level_up_inner

let level_up_page m =
  if not (level_up_box m) then None
  else if white m plus_id then Some 2
  else Some 1

let party_behind m =
  Solid_color.holds m background_id
    (Solid_color.is_solid ~ratio:teal ~max_distance:max_border_distance
       ~max_stddev_sum:max_teal_stddev_sum)

let move_learn_box m = window m yes_no_ids yes_no_inner && party_behind m
