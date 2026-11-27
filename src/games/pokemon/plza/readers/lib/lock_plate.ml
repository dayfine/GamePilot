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

(* The Poke Ball's red half and the female mark's pinkish red alike, and
   white: wider than the fork's (red over 190, white over 215), as a 640x360
   frame's ball is blurred dimmer. *)
let red = Find_probe.filter { min = 0xffa00000; max = 0xffff96aa }
let white = Find_probe.filter { min = 0xffc8c8c8; max = 0xffffffff }
let red_filter = 0
let mark_id = "lock_plate.mark"
let min_mark_area = 40.
let empty (box : Native_box.t) = box.w <= 0 || box.h <= 0

let mark_probes ~picture b =
  let box = mark_box b in
  if empty box then []
  else
    Find_probe.probe ~picture ~id:mark_id box
      (Wire.Blob_find.params ~filters:[ red; white ] ~min_area:min_mark_area ())

(* The ball: a red half at least 1.4 times as wide as high (the female mark
   is a disc, its white sign inside its red), and under it a white half: its
   top no higher than 0.35 of the red's height above the red's bottom and no
   lower than 1.5 heights below it, its centre over the red or within a
   quarter of its width beside it, and at least 0.4 times as wide. *)
let min_half_aspect = 1.4
let top_slack = 0.35
let max_drop = 1.5
let centre_slack = 0.25
let min_width_ratio = 0.4

let under (r : Wire.Blob_find.blob) (w : Wire.Blob_find.blob) =
  let bottom = r.y +. r.h and centre = w.x +. (w.w *. half) in
  w.y >= bottom -. (top_slack *. r.h)
  && w.y <= bottom +. (max_drop *. r.h)
  && centre >= r.x -. (centre_slack *. r.w)
  && centre <= r.x +. r.w +. (centre_slack *. r.w)
  && w.w >= min_width_ratio *. r.w

let ball blobs =
  let reds, whites =
    List.partition
      (fun (b : Wire.Blob_find.blob) -> b.filter = red_filter)
      blobs
  in
  List.exists
    (fun (r : Wire.Blob_find.blob) ->
      r.w >= min_half_aspect *. r.h && List.exists (under r) whites)
    reds

let caught m b =
  if empty (mark_box b) then Some false
  else
    match Effects.probe m mark_id with
    | Some (Wire.Find { blobs }) -> Some (ball blobs)
    | Some
        ( Wire.Color_stats _ | Wire.Template_match _ | Wire.Template_ncc _
        | Wire.Color_count _ | Wire.Line_shares _ | Wire.Other _ )
    | None ->
        None
