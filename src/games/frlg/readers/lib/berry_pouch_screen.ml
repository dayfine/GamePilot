let left_id = "pouch.left"
let right_id = "pouch.right"
let band_id = "pouch.band"

(* (107, 156, 239) and (165, 206, 239) as channel shares. *)
let border : Wire.rgb = { r = 0.213; g = 0.311; b = 0.476 }
let band : Wire.rgb = { r = 0.270; g = 0.338; b = 0.392 }
let max_distance = 0.08
let max_stddev_sum = 20.

(* The list window's border columns at x 86 and 232, from y 16 (its upper
   half: a menu or message lower down does not cover it); the band at y 4. *)
let boxes : (string * Wire.box * Wire.rgb) list =
  [
    (left_id, Game_pixels.box { x = 86.; y = 16.; w = 1.; h = 40. }, border);
    (right_id, Game_pixels.box { x = 232.; y = 16.; w = 1.; h = 40. }, border);
    (band_id, Game_pixels.box { x = 10.; y = 4.; w = 70.; h = 2. }, band);
  ]

let probes = List.map (fun (id, b, _) -> Solid_color.probe ~id b) boxes

let berry_pouch m =
  List.for_all
    (fun (id, _, ratio) ->
      Solid_color.holds m id
        (Solid_color.is_solid ~ratio ~max_distance ~max_stddev_sum))
    boxes
