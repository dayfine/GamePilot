let top : Native_box.t = { x = 420; y = 165; w = 1080; h = 14 }
let bottom : Native_box.t = { x = 420; y = 905; w = 820; h = 14 }
let left : Native_box.t = { x = 300; y = 300; w = 40; h = 500 }
let right : Native_box.t = { x = 1575; y = 300; w = 40; h = 500 }

(* The arrow bobs: y 844 to 872 over console B's frames. *)
let arrow : Native_box.t = { x = 1420; y = 835; w = 46; h = 45 }
let white_min = 200
let dark_max = 110
let white = Color_count.white white_min
let dark = Color_count.dark dark_max
let min_card = 0.90
let max_outside = 0.10
let min_arrow = 0.04
let min_around_arrow = 0.60

(* Each probe: its id, box, colour range, and whether its share must be at
   least ([true]) or at most a bound. *)
let checks =
  [
    ("info_card.top", top, white, true, min_card);
    ("info_card.bottom", bottom, white, true, min_card);
    ("info_card.left", left, white, false, max_outside);
    ("info_card.right", right, white, false, max_outside);
    ("info_card.arrow", arrow, dark, true, min_arrow);
    ("info_card.around_arrow", arrow, white, true, min_around_arrow);
  ]

let probes ~picture =
  List.concat_map
    (fun (id, box, range, _, _) -> Color_count.probe ~picture ~id box range)
    checks

let holds m (id, _, _, at_least, bound) =
  match Color_count.share m id with
  | Some s -> if at_least then s >= bound else s <= bound
  | None -> false

let shown m = List.for_all (holds m) checks

let describe m =
  String.concat " "
    (List.map
       (fun (id, _, _, _, _) ->
         Option.fold ~none:"-" ~some:(Printf.sprintf "%.2f")
           (Color_count.share m id))
       checks)
