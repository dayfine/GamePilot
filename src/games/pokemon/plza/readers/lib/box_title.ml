let id = "box_title.band"
let band : Native_box.t = { x = 320; y = 336; w = 290; h = 34 }
let min_ink = 0.06
let tolerance_px = 3
let one_min_px = 3
let one_max_px = 10
let one_max_share = 0.6

type t = { glyphs : (int * int) list }

let probes ~picture = Pixel_shares.probe ~picture ~id band Pixel_shares.white

(* Column [i] of [n] across the band, in 1080p pixels. *)
let column_x ~n i = band.x + (i * band.w / n)

(* Runs of inked columns, by index, left to right. *)
let runs columns =
  let close start i acc =
    match start with Some s -> (s, i - 1) :: acc | None -> acc
  in
  let step (start, acc, i) share =
    match (share >= min_ink, start) with
    | true, None -> (Some i, acc, i + 1)
    | true, Some _ -> (start, acc, i + 1)
    | false, _ -> (None, close start i acc, i + 1)
  in
  let start, acc, n = List.fold_left step (None, [], 0) columns in
  List.rev (close start n acc)

let read m =
  match Pixel_shares.lines m id with
  | None -> None
  | Some { columns; _ } -> (
      let n = List.length columns in
      let px (a, b) = (column_x ~n a, column_x ~n (b + 1) - 1) in
      match runs columns with
      | [] -> None
      | rs -> Some { glyphs = List.map px rs })

let width (a, b) = b - a + 1
let near a b = abs (a - b) <= tolerance_px

let last_two t =
  match List.rev t.glyphs with
  | last :: before :: _ -> Some (before, last)
  | _ -> None

let same a b =
  match (a.glyphs, b.glyphs, last_two a, last_two b) with
  | (l1, _) :: _, (l2, _) :: _, Some (_, (x1, y1)), Some (_, (x2, y2)) ->
      near l1 l2 && near x1 x2 && near y1 y2
  | _ -> false

let box_one t =
  match last_two t with
  | Some (before, last) ->
      width last >= one_min_px
      && width last <= one_max_px
      && float_of_int (width last)
         <= one_max_share *. float_of_int (width before)
  | None -> false

let text t =
  String.concat " " (List.map (fun g -> string_of_int (width g)) t.glyphs)
