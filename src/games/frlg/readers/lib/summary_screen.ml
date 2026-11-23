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

(* Page [p]: marks before it tan, its own white, after it blue. *)
let shows m p =
  List.for_all2
    (fun index id ->
      let mark = index + 1 in
      Solid_color.holds m id
        (if mark < p then solid tan
         else if mark = p then fun s -> Solid_color.is_white s || solid gold s
         else solid blue))
    (List.init (List.length mark_ids) Fun.id)
    mark_ids

let page m = List.find_opt (shows m) [ 1; 2; 3 ]
