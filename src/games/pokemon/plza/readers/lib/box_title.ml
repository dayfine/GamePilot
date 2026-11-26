let id = "box_title.band"
let band : Native_box.t = { x = 320; y = 336; w = 290; h = 34 }
let min_ink = 0.06
let tolerance_px = 3
let digit_min_px = 10

type t = { left : int; right : int }

let probes ~picture = Pixel_shares.probe ~picture ~id band Pixel_shares.white

(* Column [i] of [n] across the band, in 1080p pixels. *)
let column_x ~n i = band.x + (i * band.w / n)

let inked columns =
  List.concat
    (List.mapi (fun i share -> if share >= min_ink then [ i ] else []) columns)

let read m =
  match Pixel_shares.lines m id with
  | None -> None
  | Some { columns; _ } -> (
      let n = List.length columns in
      match inked columns with
      | [] -> None
      | first :: rest ->
          let last = List.fold_left (fun _ i -> i) first rest in
          Some { left = column_x ~n first; right = column_x ~n last })

let width t = t.right - t.left

let same a b =
  abs (a.left - b.left) <= tolerance_px
  && abs (a.right - b.right) <= tolerance_px

let one_more_digit ~before ~after = width after - width before >= digit_min_px
