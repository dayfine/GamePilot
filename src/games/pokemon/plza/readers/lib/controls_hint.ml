(* The card, its "?" and the strips around it, 1080p pixels at the card's
   lowest-row height. *)
let card : Native_box.t = { x = 947; y = 872; w = 24; h = 28 }
let glyph : Native_box.t = { x = 955; y = 879; w = 8; h = 7 }

let around : (string * Native_box.t) list =
  [
    ("left", { x = 928; y = 872; w = 14; h = 28 });
    ("right", { x = 980; y = 872; w = 14; h = 28 });
    ("above", { x = 945; y = 856; w = 30; h = 8 });
    ("below", { x = 945; y = 906; w = 30; h = 8 });
  ]

let id name = "controls_hint." ^ name
let highest = -60
let lowest = 20
let step = 2
let card_min = 0.80

(* Not the fork's 0.70: a frame a tenth brighter turns the "?"'s bluish edges
   sky blue (0.80 on 0210); a sky behind is 1.00. *)
let glyph_max = 0.90
let around_max = 0.10

(* The box over every height it is looked at. *)
let slide (b : Native_box.t) : Native_box.t =
  { b with y = b.y + highest; h = b.h + lowest - highest }

let boxes = ("card", card) :: ("glyph", glyph) :: around

let probes ~picture =
  List.concat_map
    (fun (name, b) ->
      Pixel_shares.probe ~picture ~id:(id name) (slide b) Pixel_shares.sky_blue)
    boxes

(* The box's share at [dy]; [None] when its probe is missing. *)
let share m name (b : Native_box.t) dy =
  Option.bind
    (Pixel_shares.lines m (id name))
    (fun (t : Wire.Line_shares.t) ->
      Pixel_shares.window t.rows ~first:(dy - highest) ~count:b.h)

let below_max m dy (name, b) =
  match share m name b dy with Some s -> s <= around_max | None -> false

let card_at m dy =
  match (share m "card" card dy, share m "glyph" glyph dy) with
  | Some c, Some g ->
      c >= card_min && g <= glyph_max && List.for_all (below_max m dy) around
  | None, _ | _, None -> false

let shown m =
  let heights =
    List.init (((lowest - highest) / step) + 1) (fun i -> highest + (i * step))
  in
  List.exists (card_at m) heights
