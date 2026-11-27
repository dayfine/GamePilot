module L = Wire.Line_shares

let hint_id = "battle_hud.hint"

let hint_area =
  Native_box.of_fractions
    { left = 0.40; top = 0.84; width = 0.20; height = 0.10 }

let frame_w = float_of_int Native_box.frame_width
let frame_h = float_of_int Native_box.frame_height

(* A box the fork writes in 1080p pixels. *)
type pixels = { x : float; y : float; w : float; h : float }

let px { x; y; w; h } =
  Native_box.of_fractions
    {
      left = x /. frame_w;
      top = y /. frame_h;
      width = w /. frame_w;
      height = h /. frame_h;
    }

(* The level badge and the HP bar. *)
let badge = px { x = 240.; y = 799.; w = 80.; h = 19. }
let bar = px { x = 236.; y = 882.; w = 204.; h = 20. }
let badge_share = 0.5
let bar_share = 0.8
let badge_id = "battle_hud.badge"
let bar_id i = Printf.sprintf "battle_hud.bar.%d" i

(* Channel [c] of (r, g, b) weighted [w]. *)
let weight c w = match c with 0 -> (w, 0, 0) | 1 -> (0, w, 0) | _ -> (0, 0, w)
let add (a, b, c) (d, e, f) = (a + d, b + e, c + f)

(* [ca - cb] compared with [value]. *)
let diff ca cb op value : L.comparison =
  { weights = add (weight ca 1) (weight cb (-1)); op; value }

let fill_spread = 90

(* The bar's fill with [i] the strongest channel and [j] the weakest (the
   first of equals), so each fill pixel passes one test. *)
let fill_test (i, j) : L.test =
  let k = 3 - i - j in
  [
    diff i j Greater_equal fill_spread;
    diff i k (if k < i then Greater else Greater_equal) 0;
    diff k j (if k < j then Greater else Greater_equal) 0;
  ]

let trough_spread = 25
let trough_sum_min = 180
let trough_sum_max = 422

(* Channels within 25 of each other, mean (summed, then divided by 3 and
   truncated) 60 to 140. *)
let trough : L.test =
  List.concat_map
    (fun (a, b) ->
      [ diff a b Less_equal trough_spread; diff b a Less_equal trough_spread ])
    [ (0, 1); (0, 2); (1, 2) ]
  @ L.
      [
        { weights = (1, 1, 1); op = Greater_equal; value = trough_sum_min };
        { weights = (1, 1, 1); op = Less_equal; value = trough_sum_max };
      ]

let bar_tests =
  List.map fill_test [ (0, 1); (0, 2); (1, 0); (1, 2); (2, 0); (2, 1) ]
  @ [ trough ]

(* The markers' five slots, one probe across them. *)
type marker_geom = {
  slot_count : int;
  first_centre : int;
  spacing : int;
  w : int;
  h : int;
  top : int;
  triangle_share : float;
  no_triangle_share : float;
  dot_share_min : float;
  dot_share_max : float;
  dots_min : int;
  dot_spread : int;
}

let mk =
  {
    slot_count = 5;
    first_centre = 405;
    spacing = 27;
    w = 16;
    h = 12;
    top = 800;
    triangle_share = 0.2;
    no_triangle_share = 0.05;
    dot_share_min = 0.06;
    dot_share_max = 0.5;
    dots_min = 3;
    dot_spread = 30;
  }

let slot_centres =
  List.init mk.slot_count (fun i -> mk.first_centre + (mk.spacing * i))

let first_slot_left = mk.first_centre - (mk.w / 2)

let markers_span =
  px
    {
      x = float_of_int first_slot_left;
      y = float_of_int mk.top;
      w = float_of_int ((mk.spacing * (mk.slot_count - 1)) + mk.w);
      h = float_of_int mk.h;
    }

let triangle_id = "battle_hud.markers.triangle"
let dot_id = "battle_hud.markers.dot"

let triangle : L.test =
  [
    { weights = (1, 0, 0); op = Less_equal; value = 70 };
    { weights = (0, 1, 0); op = Greater_equal; value = 150 };
    { weights = (0, 1, 0); op = Less_equal; value = 210 };
    { weights = (0, 0, 1); op = Greater_equal; value = 225 };
  ]

(* Every channel over 200 and within [spread] of the others. *)
let white_within spread : L.test =
  L.
    [
      { weights = (1, 0, 0); op = Greater; value = 200 };
      { weights = (0, 1, 0); op = Greater; value = 200 };
      { weights = (0, 0, 1); op = Greater; value = 200 };
    ]
  @ List.concat_map
      (fun (a, b) -> [ diff a b Less_equal spread; diff b a Less_equal spread ])
      [ (0, 1); (0, 2); (1, 2) ]

(* The trainer's six balls, one probe across their tops and one their
   bottoms. *)
type ball_geom = {
  count : int;
  first_x : float;
  spacing : int;
  w : int;
  share : float;
  white_spread : int;
}

let bl =
  {
    count = 6;
    first_x = 857.5;
    spacing = 41;
    w = 14;
    share = 0.4;
    white_spread = 40;
  }

let ball_left = bl.first_x -. (float_of_int bl.w /. 2.)

(* A row of the balls: its [y] and [h]. *)
let ball_span (row : pixels) =
  px
    {
      row with
      x = ball_left;
      w = float_of_int ((bl.spacing * (bl.count - 1)) + bl.w);
    }

let ball_tops = ball_span { x = 0.; y = 60.; w = 0.; h = 6. }
let ball_bottoms = ball_span { x = 0.; y = 72.; w = 0.; h = 8. }
let ball_top_id = "battle_hud.balls.top"
let ball_bottom_id = "battle_hud.balls.bottom"

let coral : L.test =
  [
    { weights = (1, 0, 0); op = Greater; value = 190 };
    { weights = (1, -1, 0); op = Greater; value = 70 };
    { weights = (1, 0, -1); op = Greater; value = 60 };
  ]

let bar_probes ~picture =
  List.concat
    (List.mapi
       (fun i test -> Pixel_shares.probe ~picture ~id:(bar_id i) bar test)
       bar_tests)

let probes ~picture ~assets =
  List.concat
    [
      Interact_prompt.probes_over ~picture ~assets ~id:hint_id hint_area;
      Pixel_shares.probe ~picture ~id:badge_id badge Pixel_shares.dim_cyan;
      bar_probes ~picture;
      Pixel_shares.probe ~picture ~id:triangle_id markers_span triangle;
      Pixel_shares.probe ~picture ~id:dot_id markers_span
        (white_within mk.dot_spread);
      Pixel_shares.probe ~picture ~id:ball_top_id ball_tops coral;
      Pixel_shares.probe ~picture ~id:ball_bottom_id ball_bottoms
        (white_within bl.white_spread);
    ]

let hint_shown m = Interact_prompt.shown_over m hint_id

(* The share of a whole probe box: the mean of its rows. *)
let box_share m id =
  Option.bind (Pixel_shares.lines m id) (fun (t : L.t) ->
      Pixel_shares.window t.rows ~first:0 ~count:(List.length t.rows))

(* The summed shares of the bar's first [count] probes. *)
let bar_shares m count =
  List.fold_left
    (fun total i ->
      Option.bind total (fun t ->
          Option.map (( +. ) t) (box_share m (bar_id i))))
    (Some 0.) (List.init count Fun.id)

let bar_total m = bar_shares m (List.length bar_tests)
let at_least share = function Some s -> s >= share | None -> false

(* The bar's fill alone: its six fill probes, the trough (the last) left
   out. *)
let fill_total m = bar_shares m (List.length bar_tests - 1)

(* The bar's left end: its first 3% of columns (6 pixels at 1080p, 2 at
   360p) mostly fill. 1 HP of 19 fills about 4%. *)
let left_end_width = 0.03
let left_end_share = 0.8

let left_end_fill m i =
  Option.bind
    (Pixel_shares.lines m (bar_id i))
    (fun (t : L.t) ->
      let columns = List.length t.columns in
      let count =
        max 1 (int_of_float (left_end_width *. float_of_int columns))
      in
      Pixel_shares.window t.columns ~first:0 ~count)

let left_end_filled m =
  at_least left_end_share
    (List.fold_left
       (fun total i ->
         Option.bind total (fun t -> Option.map (( +. ) t) (left_end_fill m i)))
       (Some 0.)
       (List.init (List.length bar_tests - 1) Fun.id))

let lead_hp m =
  if
    at_least badge_share (box_share m badge_id)
    && (at_least bar_share (bar_total m) || left_end_filled m)
  then fill_total m
  else None

let panel_shown m =
  at_least badge_share (box_share m badge_id)
  && at_least bar_share (bar_total m)

(* A slot's share in a probe across slots: the mean of its columns. *)
let column_share m id ~first ~count =
  Option.bind (Pixel_shares.lines m id) (fun (t : L.t) ->
      Pixel_shares.window t.columns ~first ~count)

type slot = Triangle | Dot | Neither

let slot m centre =
  let first = centre - (mk.w / 2) - first_slot_left in
  let share id = column_share m id ~first ~count:mk.w in
  match (share triangle_id, share dot_id) with
  | Some blue, _ when blue >= mk.triangle_share -> Triangle
  | Some blue, Some white
    when blue < mk.no_triangle_share
         && white >= mk.dot_share_min && white <= mk.dot_share_max ->
      Dot
  | _ -> Neither

let markers_shown m =
  let slots = List.map (slot m) slot_centres in
  let count kind = List.length (List.filter (( = ) kind) slots) in
  count Triangle = 1 && count Dot >= mk.dots_min

let ball_shown m i =
  let first = bl.spacing * i in
  let share id = column_share m id ~first ~count:bl.w in
  at_least bl.share (share ball_top_id)
  && at_least bl.share (share ball_bottom_id)

let trainer_balls_shown m =
  List.exists (ball_shown m) (List.init bl.count Fun.id)

let shown m =
  hint_shown m || (panel_shown m && (markers_shown m || trainer_balls_shown m))
