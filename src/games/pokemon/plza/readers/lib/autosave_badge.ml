(* The icon and the strips around it, 1080p pixels with the Chinese badge's
   icon (the leftmost). *)
let icon : Native_box.t = { x = 1603; y = 73; w = 27; h = 31 }

let around : (string * Native_box.t) list =
  [
    ("left", { x = 1570; y = 73; w = 28; h = 31 });
    ("above", { x = 1603; y = 56; w = 27; h = 14 });
    ("below", { x = 1603; y = 108; w = 27; h = 14 });
  ]

let farthest = 240
let step = 4
let icon_min_white = 0.08
let icon_max_white = 0.40
let icon_min_dim_cyan = 0.25
let around_max = 0.05
let id box test = Printf.sprintf "autosave.%s.%s" box test

(* The box over every place it is looked at. *)
let slide (b : Native_box.t) : Native_box.t = { b with w = b.w + farthest }

let tests =
  ( "icon",
    [ ("white", Pixel_shares.white); ("dim_cyan", Pixel_shares.dim_cyan) ] )
  :: List.map
       (fun (box, _) ->
         (box, [ ("white", Pixel_shares.white); ("cyan", Pixel_shares.cyan) ]))
       around

let box_named box = Option.value (List.assoc_opt box around) ~default:icon

let box_probes ~picture (box, named) =
  let probe (name, test) =
    Pixel_shares.probe ~picture ~id:(id box name) (slide (box_named box)) test
  in
  List.concat_map probe named

let probes ~picture = List.concat_map (box_probes ~picture) tests

(* The share of box [box]'s test [test] at [dx]. *)
let share m box test (b : Native_box.t) dx =
  Option.bind
    (Pixel_shares.lines m (id box test))
    (fun (t : Wire.Line_shares.t) ->
      Pixel_shares.window t.columns ~first:dx ~count:b.w)

let clear m dx (box, b) =
  let under test =
    match share m box test b dx with Some s -> s < around_max | None -> false
  in
  under "white" && under "cyan"

let icon_at m dx =
  match (share m "icon" "white" icon dx, share m "icon" "dim_cyan" icon dx) with
  | Some white, Some dim ->
      white >= icon_min_white && white <= icon_max_white
      && dim >= icon_min_dim_cyan
      && List.for_all (clear m dx) around
  | None, _ | _, None -> false

let shown m =
  List.exists (icon_at m)
    (List.init ((farthest / step) + 1) (fun i -> i * step))
