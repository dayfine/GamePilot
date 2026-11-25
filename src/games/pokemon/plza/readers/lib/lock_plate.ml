open Wire.Line_shares

type bar = { x : float; y : float; w : float; h : float }

let id = "lock_plate"
let upper_share = 0.68

let upper =
  Native_box.of_fractions
    { left = 0.; top = 0.; width = 1.; height = upper_share }

let green = [ Find_probe.filter { min = 0xff00af5a; max = 0xff5aff91 } ]
let min_area = 150.

let probes ~picture =
  Find_probe.probe ~picture ~id upper
    (Wire.Blob_find.params ~filters:green ~min_area ())

let min_width = 80.
let max_height = 24.
let min_aspect = 4.
let min_fill = 0.5

let flat (b : Wire.Blob_find.blob) =
  b.w >= min_width && b.h <= max_height
  && b.w >= min_aspect *. b.h
  && b.fill >= min_fill

(* The widest; the first of equals, as the fork keeps it. *)
let bar m =
  List.fold_left
    (fun best (b : Wire.Blob_find.blob) ->
      match best with
      | Some k when b.w <= k.w -> best
      | _ when flat b -> Some { x = b.x; y = b.y; w = b.w; h = b.h }
      | _ -> best)
    None (Find_probe.read m id)

let frame_width = float_of_int Native_box.frame_width
let frame_height = float_of_int Native_box.frame_height
let half = 0.5

let centre b =
  ((b.x +. (b.w *. half)) /. frame_width, (b.y +. (b.h *. half)) /. frame_height)

(* The mark's box, as the fork truncates its pixel bounds. *)
let mark_left = 0.6
let mark_right = 1.5
let mark_top = 0.85
let mark_bottom = 0.45

let mark_box b : Native_box.t =
  let trunc v = int_of_float (Float.max 0. v) in
  let x0 = trunc (b.x +. (mark_left *. b.w))
  and x1 = min Native_box.frame_width (trunc (b.x +. (mark_right *. b.w)))
  and y0 = trunc (b.y -. (mark_top *. b.w))
  and y1 = trunc (b.y -. (mark_bottom *. b.w)) in
  { x = x0; y = y0; w = x1 - x0; h = y1 - y0 }

let red =
  [
    { weights = (1, 0, 0); op = Greater; value = 190 };
    { weights = (1, -1, 0); op = Greater; value = 70 };
    { weights = (1, 0, -1); op = Greater; value = 50 };
    { weights = (0, -1, 1); op = Greater_equal; value = -15 };
  ]

let white =
  [
    { weights = (1, 0, 0); op = Greater; value = 215 };
    { weights = (0, 1, 0); op = Greater; value = 215 };
    { weights = (0, 0, 1); op = Greater; value = 215 };
  ]

let red_id = "lock_plate.mark.red"
let white_id = "lock_plate.mark.white"
let empty (box : Native_box.t) = box.w <= 0 || box.h <= 0

let mark_probes ~picture b =
  let box = mark_box b in
  if empty box then []
  else
    Pixel_shares.probe ~picture ~id:red_id box red
    @ Pixel_shares.probe ~picture ~id:white_id box white

(* 15 at 720p, scaled by area to 1080p. *)
let min_pixels_720p = 15.
let lines_720p = 720.
let scale = float_of_int Native_box.frame_height /. lines_720p
let min_pixels = min_pixels_720p *. scale *. scale

(* The pixels passing: each row's share times its width. *)
let count m id =
  Option.map
    (fun (t : Wire.Line_shares.t) ->
      let width = float_of_int (List.length t.columns) in
      Float.round (List.fold_left (fun s r -> s +. (r *. width)) 0. t.rows))
    (Pixel_shares.lines m id)

let caught m b =
  if empty (mark_box b) then Some false
  else
    match (count m red_id, count m white_id) with
    | Some r, Some w -> Some (r >= min_pixels && w >= min_pixels)
    | _ -> None
