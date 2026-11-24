type pocket = Items | Key_items | Poke_balls

let pocket_name = function
  | Items -> "items"
  | Key_items -> "keyitems"
  | Poke_balls -> "balls"

let shadow_id = "bag.shadow"
let underline_id = "bag.underline"
let top_id = "bag.top"
let right_id = "bag.right"
let left_arrow_id = "bag.arrow_left"
let right_arrow_id = "bag.arrow_right"

(* The fork's colors: grey RGB(159, 159, 159), orange (255, 152, 50), yellow
   (255, 225, 93), as channel shares. *)
let grey : Wire.rgb = { r = 0.333; g = 0.333; b = 0.333 }
let orange : Wire.rgb = { r = 0.558; g = 0.333; b = 0.109 }
let yellow : Wire.rgb = { r = 0.445; g = 0.393; b = 0.162 }
let max_distance = 0.25
let max_stddev_sum = 20.

let solid_boxes : (string * Wire.box * Wire.rgb) list =
  [
    (shadow_id, { x = 0.131250; y = 0.608173; w = 0.068269; h = 0.001442 }, grey);
    ( underline_id,
      { x = 0.043269; y = 0.137259; w = 0.279808; h = 0.005769 },
      orange );
    (top_id, { x = 0.029808; y = 0.029086; w = 0.550000; h = 0.003606 }, yellow);
    ( right_id,
      { x = 0.977404; y = 0.034134; w = 0.005288; h = 0.597837 },
      yellow );
  ]

(* Measured on mGBA (pixel (255, 82, 0)) and Switch ((250, 92, 2)): the
   girl's salmon background, (236, 148, 107), stays out. The arrows bob 3 pixels
   sideways within x 0-12 and 64-80, y 64-80; the bag's own red strap ends at
   x 61. *)
let left_arrow = Game_pixels.box { x = 0.; y = 64.; w = 12.; h = 16. }
let right_arrow = Game_pixels.box { x = 64.; y = 64.; w = 16.; h = 16. }

(* Inside an item's action menu, between its first two rows (USE or CHECK at
   y 93-99, GIVE at y 111-117): the menu's white, where the list shows its
   cream, item names and counts, and a message its text. Measured on mGBA
   (mg-04 testing run 6's Escape Rope menu: the border at x 169, y 81; the
   white from x 174 to 233). *)
let item_menu_id = "bag.item_menu"
let item_menu_box = Game_pixels.box { x = 200.; y = 102.; w = 30.; h = 6. }

let arrow_red : Color_count.range =
  { low = { r = 180; g = 0; b = 0 }; high = { r = 255; g = 120; b = 60 } }

let min_arrow_share = 0.05

(* Rows from y 11, 16 apart, 12 high; the arrow at x 88-96 (the fork's). *)
let row_top = 11.
let row_step = 16.

let row_box index : Wire.box =
  Game_pixels.box
    {
      x = 88.;
      y = row_top +. (row_step *. float_of_int index);
      w = 8.;
      h = 12.;
    }

let rows_shown = 6
let cursor = Cursor_column.make ~prefix:"bag" (List.init rows_shown row_box)
let arrow_probe id box = Color_count.probe ~id box arrow_red

let probes =
  List.map (fun (id, b, _) -> Solid_color.probe ~id b) solid_boxes
  @ [
      arrow_probe left_arrow_id left_arrow;
      arrow_probe right_arrow_id right_arrow;
    ]
  @ Cursor_column.probes cursor

let item_menu_probes = [ Solid_color.probe ~id:item_menu_id item_menu_box ]

let bag_open m =
  List.for_all
    (fun (id, _, ratio) ->
      Solid_color.holds m id
        (Solid_color.is_solid ~ratio ~max_distance ~max_stddev_sum))
    solid_boxes

(* The boxes along the top: an item's action menu never covers them. *)
let top_boxes =
  List.filter (fun (id, _, _) -> id = underline_id || id = top_id) solid_boxes

let solid m boxes =
  List.for_all
    (fun (id, _, ratio) ->
      Solid_color.holds m id
        (Solid_color.is_solid ~ratio ~max_distance ~max_stddev_sum))
    boxes

let arrow m id =
  Option.fold ~none:false
    ~some:(fun s -> s >= min_arrow_share)
    (Color_count.share m id)

let pocket m =
  if not (bag_open m) then None
  else
    match (arrow m left_arrow_id, arrow m right_arrow_id) with
    | false, true -> Some Items
    | true, true -> Some Key_items
    | true, false -> Some Poke_balls
    | false, false -> None

let item_menu m =
  solid m top_boxes
  && Solid_color.holds m item_menu_id (fun s -> Solid_color.is_white s)
  && (not (arrow m left_arrow_id))
  && not (arrow m right_arrow_id)

let cursor_row m = if bag_open m then Cursor_column.row cursor m else None
