module T = Switch.Timed_press
module Title = Plza_readers.Box_title

let page_l : T.t = { button = L; hold_ms = 80; cooldown_ms = 800 }
let hold_ms = 1000.
let title_ms = 3000
let max_ls = 32

let on_boxes m =
  if Plza_readers.Boxes_screen.shown m then Title.read m else None

(* The title, the same for [hold_ms] on the Boxes. *)
let steady () =
  let first = ref None in
  fun (m : Effects.measurements) ->
    match (on_boxes m, !first) with
    | None, _ ->
        first := None;
        None
    | Some t, Some (t0, since) when Title.same t t0 ->
        if m.t_ms -. since >= hold_ms then Some t else None
    | Some t, _ ->
        first := Some (t, m.t_ms);
        None

let title () =
  Screen_graph.Held_screen.wait_for ~timeout_ms:title_ms (steady ())

let not_found ls t =
  Error
    (Printf.sprintf "no Box 1 title after %d L (glyphs %s)" ls (Title.text t))

let to_box_one ~log =
  let rec go ls =
    match title () with
    | None -> Error (Printf.sprintf "no box title read after %d L" ls)
    | Some t when Title.box_one t ->
        log (Printf.sprintf "Box 1, after %d L." ls);
        Ok ()
    | Some t when ls >= max_ls -> not_found ls t
    | Some _ ->
        T.press page_l;
        go (ls + 1)
  in
  go 0
