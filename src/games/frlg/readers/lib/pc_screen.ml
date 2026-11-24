type screen =
  | Overworld
  | Text
  | Pc_list
  | Storage_menu
  | Party_panel
  | Box_grid
  | Mon_menu
  | Box_chooser
  | Yes_no
  | Other

type view = { screen : screen; cursor : int option }

let storage_menu_rows = 5
let pc_list_rows = 4
let party_panel_rows = 7
let mon_menu_rows = 5
let yes_no_rows = 2
let gba x y w h = Game_pixels.box { x; y; w; h }

(* The fork's patches, each plain on its screen (see the .mli). *)
let patches =
  [
    ("pc.list", gba 100. 58. 20. 14.);
    ("pc.storage", gba 128. 58. 18. 30.);
    ("pc.data_panel", gba 3. 100. 4. 40.);
    ("pc.mon_menu", gba 205. 72. 25. 14.);
    ("pc.yes_no", gba 200. 86. 32. 4.);
    ("pc.chooser", gba 160. 68. 30. 18.);
    ("pc.party_panel", gba 122. 96. 12. 36.);
    ("pc.message", gba 10. 148. 160. 4.);
    ("pc.game", gba 0. 0. 240. 160.);
  ]

(* The share of an arrow's box an arrow darkens (0.31 to 0.37 measured; text
   and frames nearby under 0.25). *)
let arrow_dark = 0.25

(* The share of a party slot's hand area the hand's white covers (0.10 to
   0.16 measured; a Pokémon's icon at most 0.03). *)
let hand_white = 0.06

(* The game picture's mean channel sum under this: a fade. *)
let dark_screen = 150.

let dark : Color_count.range =
  { low = { r = 0; g = 0; b = 0 }; high = { r = 110; g = 110; b = 110 } }

let white : Color_count.range =
  { low = { r = 235; g = 235; b = 235 }; high = { r = 255; g = 255; b = 255 } }

(* An arrow column: [rows] boxes 7 by 10 from (x, y), [step] apart. *)
let column name ~x ~y ~step rows =
  List.init rows (fun row ->
      ( Printf.sprintf "pc.%s.row%d" name row,
        gba x (y +. (step *. float_of_int row)) 7. 10. ))

let pc_rows = column "menu" ~x:9. ~y:12. ~step:16. storage_menu_rows
let mon_rows = column "mon" ~x:159. ~y:44. ~step:16. mon_menu_rows
let yes_no_rows_boxes = column "yes_no" ~x:191. ~y:91. ~step:14. yes_no_rows

(* The party panel's slot under the hand: the lead's hand area above its box;
   a right slot's above and on its box, 24 apart (the top one cut by the
   screen's top); CANCEL's above CANCEL. *)
let hand_areas =
  let right slot =
    let bottom = (24. *. float_of_int (slot - 1)) +. 11. in
    let top = Float.max 0. (bottom -. 25.) in
    gba 138. top 28. (bottom -. top)
  in
  List.mapi
    (fun i b -> (Printf.sprintf "pc.hand%d" i, b))
    ((gba 92. 36. 28. 26. :: List.init 5 (fun i -> right (i + 1)))
    @ [ gba 138. 118. 28. 24. ])

let probes =
  List.map (fun (id, b) -> Solid_color.probe ~id b) patches
  @ List.map
      (fun (id, b) -> Color_count.probe ~id b dark)
      (pc_rows @ mon_rows @ yes_no_rows_boxes)
  @ List.map (fun (id, b) -> Color_count.probe ~id b white) hand_areas
  @ Start_menu.probes

let holds m id test = Solid_color.holds m id test
let is_white m id = holds m id (fun s -> Solid_color.is_white s)
let share m id = Option.value (Color_count.share m id) ~default:0.

(* The one row whose arrow box holds an arrow; none if none or several do. *)
let arrow_row m boxes =
  match
    List.filteri (fun _ (id, _) -> share m id >= arrow_dark) boxes
    |> List.map fst
  with
  | [ id ] -> List.find_index (fun (i, _) -> i = id) boxes
  | _ -> None

let first n l = List.filteri (fun i _ -> i < n) l

let party_panel_cursor m =
  let best, _ =
    List.fold_left
      (fun (best, best_share) (i, (id, _)) ->
        let s = share m id in
        if s >= best_share then (Some i, s) else (best, best_share))
      (None, hand_white)
      (List.mapi (fun i h -> (i, h)) hand_areas)
  in
  best

let box_screen m =
  if is_white m "pc.mon_menu" then
    { screen = Mon_menu; cursor = arrow_row m mon_rows }
  else if is_white m "pc.yes_no" then
    { screen = Yes_no; cursor = arrow_row m yes_no_rows_boxes }
  else if
    holds m "pc.chooser"
      (Solid_color.is_solid
         ~ratio:{ r = 0.445; g = 0.390; b = 0.165 }
         ~max_distance:0.08 ~max_stddev_sum:30.)
  then { screen = Box_chooser; cursor = None }
  else if
    holds m "pc.party_panel"
      (Solid_color.is_solid
         ~ratio:{ r = 0.137; g = 0.426; b = 0.437 }
         ~max_distance:0.10 ~max_stddev_sum:80.)
  then { screen = Party_panel; cursor = party_panel_cursor m }
  else { screen = Box_grid; cursor = None }

let other = { screen = Other; cursor = None }

let menus m =
  let storage = is_white m "pc.storage" in
  let rows = if storage then storage_menu_rows else pc_list_rows in
  Option.map
    (fun row ->
      {
        screen = (if storage then Storage_menu else Pc_list);
        cursor = Some row;
      })
    (arrow_row m (first rows pc_rows))

let read m =
  if holds m "pc.game" (fun s -> Solid_color.sum s.mean < dark_screen) then
    other
  else if
    holds m "pc.data_panel"
      (Solid_color.is_solid
         ~ratio:{ r = 0.311; g = 0.319; b = 0.370 }
         ~max_distance:0.06 ~max_stddev_sum:80.)
  then box_screen m
  else
    match if is_white m "pc.list" then menus m else None with
    | Some v -> v
    | None ->
        if
          holds m "pc.message"
            (Solid_color.is_white ~min_sum:500. ~max_stddev_sum:40.)
        then { screen = Text; cursor = None }
        else if Start_menu.start_menu_open m then other
        else { screen = Overworld; cursor = None }

let screen_name = function
  | Overworld -> "overworld"
  | Text -> "text"
  | Pc_list -> "PC list"
  | Storage_menu -> "storage menu"
  | Party_panel -> "party panel"
  | Box_grid -> "box grid"
  | Mon_menu -> "Pokemon's menu"
  | Box_chooser -> "box chooser"
  | Yes_no -> "YES/NO"
  | Other -> "other"
