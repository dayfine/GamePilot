let right_id = "load_menu.right"
let left_id = "load_menu.left"
let save_id = "load_menu.save"

let boxes : (string * Wire.box) list =
  [
    (right_id, { x = 0.941846; y = 0.0190769; w = 0.0516923; h = 0.960577 });
    (left_id, { x = 0.00646154; y = 0.0180385; w = 0.0566154; h = 0.961615 });
    (save_id, { x = 0.836; y = 0.0595769; w = 0.0578462; h = 0.0747692 });
  ]

let probes = List.map (fun (id, box) -> Solid_color.probe ~id box) boxes

(* The fork's colors and is_solid()'s defaults. *)
let blue : Wire.rgb = { r = 0.244; g = 0.282; b = 0.474 }
let white : Wire.rgb = { r = 0.25; g = 0.38; b = 0.369 }
let max_distance = 0.15
let max_stddev_sum = 10.

let solid m id ratio =
  Solid_color.holds m id
    (Solid_color.is_solid ~ratio ~max_distance ~max_stddev_sum)

let load_menu_open m =
  solid m right_id blue && solid m left_id blue && solid m save_id white
