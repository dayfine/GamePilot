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
let gba (b : Wire.box) = Game_pixels.box b

(* The fork's patches, each plain on its screen (see the .mli), in GBA
   pixels. *)
let patches =
  [
    ("pc.list", gba { x = 100.; y = 58.; w = 20.; h = 14. });
    ("pc.storage", gba { x = 128.; y = 58.; w = 18.; h = 30. });
    ("pc.data_panel", gba { x = 3.; y = 100.; w = 4.; h = 40. });
    ("pc.mon_menu", gba { x = 205.; y = 72.; w = 25.; h = 14. });
    ("pc.yes_no", gba { x = 200.; y = 86.; w = 32.; h = 4. });
    (* Top yellow margin of the box chooser, above the box name's glyphs
       (y 76..85): the fork's (160, 68, 30, 18) sits over long box names such as
       8-character ACE names and blows stddev past 30. *)
    ("pc.chooser", gba { x = 136.; y = 69.; w = 48.; h = 6. });
    ("pc.party_panel", gba { x = 122.; y = 96.; w = 12.; h = 36. });
    ("pc.message", gba { x = 10.; y = 148.; w = 160.; h = 4. });
    ( "pc.game",
      gba { x = 0.; y = 0.; w = Game_pixels.width; h = Game_pixels.height } );
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

type column = { left : float; top : float; step : float }
(** An arrow column: boxes {!arrow} wide and high from (left, top), [step]
    apart. *)

let arrow : Wire.box = { x = 0.; y = 0.; w = 7.; h = 10. }

let column name (c : column) rows =
  List.init rows (fun row ->
      ( Printf.sprintf "pc.%s.row%d" name row,
        gba { arrow with x = c.left; y = c.top +. (c.step *. float_of_int row) }
      ))

let pc_column = { left = 9.; top = 12.; step = 16. }
let mon_column = { left = 159.; top = 44.; step = 16. }
let withdraw_shift = 8

let withdraw_column =
  { mon_column with left = mon_column.left -. float_of_int withdraw_shift }

let yes_no_column = { left = 191.; top = 91.; step = 14. }
let pc_rows = column "menu" pc_column storage_menu_rows
let mon_rows = column "mon" mon_column mon_menu_rows
let withdraw_rows = column "withdraw" withdraw_column mon_menu_rows
let yes_no_rows_boxes = column "yes_no" yes_no_column yes_no_rows

(* The party panel's slot under the hand: the lead's hand area above its box;
   a right slot's above and on its box, [pitch] apart (the top one cut by the
   screen's top); CANCEL's above CANCEL. *)
type hands = {
  lead : Wire.box;
  right_x : float;
  pitch : float;
  first_bottom : float;
  reach : float;
  cancel : Wire.box;
}

let hands =
  {
    lead = { x = 92.; y = 36.; w = 28.; h = 26. };
    right_x = 138.;
    pitch = 24.;
    first_bottom = 11.;
    reach = 25.;
    cancel = { x = 138.; y = 118.; w = 28.; h = 24. };
  }

let right_slots = 5

let hand_areas =
  let right slot =
    let bottom =
      (hands.pitch *. float_of_int (slot - 1)) +. hands.first_bottom
    in
    let top = Float.max 0. (bottom -. hands.reach) in
    gba { x = hands.right_x; y = top; w = hands.lead.w; h = bottom -. top }
  in
  List.mapi
    (fun i b -> (Printf.sprintf "pc.hand%d" i, b))
    ((gba hands.lead :: List.init right_slots (fun i -> right (i + 1)))
    @ [ gba hands.cancel ])

let probes =
  List.map (fun (id, b) -> Solid_color.probe ~id b) patches
  @ List.map
      (fun (id, b) -> Color_count.probe ~id b dark)
      (pc_rows @ mon_rows @ withdraw_rows @ yes_no_rows_boxes)
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

type solid = { ratio : Wire.rgb; max_distance : float; max_stddev_sum : float }
(** A patch's flat color: its channel shares and the fork's tolerances. *)

let solid c =
  Solid_color.is_solid ~ratio:c.ratio ~max_distance:c.max_distance
    ~max_stddev_sum:c.max_stddev_sum

let chooser_yellow =
  {
    ratio = { r = 0.445; g = 0.390; b = 0.165 };
    max_distance = 0.08;
    max_stddev_sum = 30.;
  }

let party_teal =
  {
    ratio = { r = 0.137; g = 0.426; b = 0.437 };
    max_distance = 0.10;
    max_stddev_sum = 80.;
  }

let data_panel_lilac =
  {
    ratio = { r = 0.311; g = 0.319; b = 0.370 };
    max_distance = 0.06;
    max_stddev_sum = 80.;
  }

type white_box = { min_sum : float; max_stddev_sum : float }

(* The message box: white, with its text in the patch. *)
let message : white_box = { min_sum = 500.; max_stddev_sum = 40. }

let box_screen m =
  if is_white m "pc.mon_menu" then
    {
      screen = Mon_menu;
      cursor =
        (match arrow_row m mon_rows with
        | Some row -> Some row
        | None -> arrow_row m withdraw_rows);
    }
  else if is_white m "pc.yes_no" then
    { screen = Yes_no; cursor = arrow_row m yes_no_rows_boxes }
  else if holds m "pc.chooser" (solid chooser_yellow) then
    { screen = Box_chooser; cursor = None }
  else if holds m "pc.party_panel" (solid party_teal) then
    { screen = Party_panel; cursor = party_panel_cursor m }
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

let text_or_overworld m =
  if
    holds m "pc.message"
      (Solid_color.is_white ~min_sum:message.min_sum
         ~max_stddev_sum:message.max_stddev_sum)
  then { screen = Text; cursor = None }
  else if Start_menu.start_menu_open m then other
  else { screen = Overworld; cursor = None }

let read m =
  if holds m "pc.game" (fun s -> Solid_color.sum s.mean < dark_screen) then
    other
  else if holds m "pc.data_panel" (solid data_panel_lilac) then box_screen m
  else
    match if is_white m "pc.list" then menus m else None with
    | Some v -> v
    | None -> text_or_overworld m

let box_screen_shown m =
  (not (holds m "pc.game" (fun s -> Solid_color.sum s.mean < dark_screen)))
  && holds m "pc.data_panel" (solid data_panel_lilac)

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
