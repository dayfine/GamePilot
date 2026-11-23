type t = { prefix : string; boxes : Wire.box list }

let make ~prefix boxes = { prefix; boxes }
let row_id t index = Printf.sprintf "%s.row%d" t.prefix index
let dark_max = 150
let min_share = 0.10
let min_lead = 3.

let dark : Color_count.range =
  {
    low = { r = 0; g = 0; b = 0 };
    high = { r = dark_max; g = dark_max; b = dark_max };
  }

let probes t =
  List.mapi
    (fun index box -> Color_count.probe ~id:(row_id t index) box dark)
    t.boxes

(* The best row and the shares of the best and of the runner-up. *)
let best shares =
  List.fold_left
    (fun (best_row, best, second) (index, s) ->
      if s > best then (index, s, best) else (best_row, best, Float.max second s))
    (-1, 0., 0.) shares

let clear_winner shares =
  let row, top, second = best shares in
  if row >= 0 && top >= min_share && top >= min_lead *. second then Some row
  else None

let row ?rows t m =
  let count = Option.value rows ~default:(List.length t.boxes) in
  let shares =
    List.init count (fun index -> Color_count.share m (row_id t index))
  in
  if List.exists Option.is_none shares then None
  else clear_winner (List.mapi (fun index s -> (index, Option.get s)) shares)
