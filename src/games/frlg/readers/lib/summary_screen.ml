let mark_ids = [ "summary.page1"; "summary.page2"; "summary.page3" ]

let mark_boxes : Wire.box list =
  [
    { x = 0.441235; y = 0.033869; w = 0.016889; h = 0.030754 };
    { x = 0.509681; y = 0.035206; w = 0.014223; h = 0.026742 };
    { x = 0.577239; y = 0.039218; w = 0.012445; h = 0.021394 };
  ]

let probes = List.map2 (fun id b -> Solid_color.probe ~id b) mark_ids mark_boxes

(* The fork's colors as channel shares. *)
let blue : Wire.rgb = { r = 0.; g = 0.3333; b = 0.6666 }
let tan : Wire.rgb = { r = 0.5117; g = 0.3763; b = 0.2294 }

(* A move's detail on page 3: its mark turns gold, (255, 182, 0) measured on
   Switch. Not in the fork. *)
let gold : Wire.rgb = { r = 0.584; g = 0.416; b = 0. }
let max_distance = 0.25
let max_stddev_sum = 20.
let solid ratio = Solid_color.is_solid ~ratio ~max_distance ~max_stddev_sum

(* The current mark differs from the tan one before it by at least this much
   (channel differences summed): a flat pale floor (Victory Road's cave floor,
   (206, 181, 156)) passes as tan and as white at once, so all three marks read
   page 3 on the overworld (mg-04b on mGBA, 2026-11-24). Not in the fork. *)
let min_mark_difference = 60.

let differs (a : Wire.rgb) (b : Wire.rgb) =
  Float.abs (a.r -. b.r) +. Float.abs (a.g -. b.g) +. Float.abs (a.b -. b.b)
  >= min_mark_difference

let unlike_before m p =
  p = 1
  ||
  match
    ( Solid_color.read m (List.nth mark_ids (p - 1)),
      Solid_color.read m (List.nth mark_ids (p - 2)) )
  with
  | Some now, Some before -> differs now.mean before.mean
  | _ -> false

(* Mark [mark]'s colour on page [p]: tan before it, white (or gold) on it,
   blue after it. *)
let mark_test ~p mark =
  if mark < p then solid tan
  else if mark = p then fun s -> Solid_color.is_white s || solid gold s
  else solid blue

(* Page [p]: each mark its colour, its own unlike the one before it. *)
let shows m p =
  unlike_before m p
  && List.for_all2
       (fun index id -> Solid_color.holds m id (mark_test ~p (index + 1)))
       (List.init (List.length mark_ids) Fun.id)
       mark_ids

let page m = List.find_opt (shows m) [ 1; 2; 3 ]
