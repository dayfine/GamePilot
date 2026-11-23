let top_id = "battle.yes_no.top"
let right_id = "battle.yes_no.right"
let box_top_id = "battle.yes_no.box_top"
let box_right_id = "battle.yes_no.box_right"
let frame_id = "battle.yes_no.frame"

(* BattleLearnDialogDetector's boxes: the YES/NO box's top and right edges
   (white), the text box's top and right edges beside it (teal). *)
let edge_boxes : (string * Wire.box) list =
  [
    (top_id, { x = 0.805; y = 0.445; w = 0.149; h = 0.006 });
    (right_id, { x = 0.962; y = 0.445; w = 0.006; h = 0.200 });
    (box_top_id, { x = 0.036; y = 0.763; w = 0.459; h = 0.014 });
    (box_right_id, { x = 0.941; y = 0.763; w = 0.006; h = 0.179 });
  ]

(* battle_yes_no_shows's YES_NO_FRAME_BOX and frame color. *)
let frame_box = Game_pixels.box { x = 184.; y = 70.; w = 8.; h = 34. }

let slate : Color_count.range =
  { low = { r = 95; g = 90; b = 120 }; high = { r = 170; g = 175; b = 240 } }

let min_frame_share = 0.2

let probes =
  Color_count.probe ~id:frame_id frame_box slate
  :: List.map (fun (id, b) -> Solid_color.probe ~id b) edge_boxes

let white m id = Solid_color.holds m id (fun s -> Solid_color.is_white s)

let framed m =
  match Color_count.share m frame_id with
  | Some share -> share >= min_frame_share
  | None -> false

let yes_no_box m =
  white m top_id && white m right_id
  && Battle_screen.teal_box m box_top_id
  && Battle_screen.teal_box m box_right_id
  && framed m
