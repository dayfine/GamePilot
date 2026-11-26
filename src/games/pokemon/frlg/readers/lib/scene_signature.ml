let cells = 3
let cell_size = 1. /. float_of_int cells
let cell_id i = Printf.sprintf "scene.%d" i

let box i : Wire.box =
  {
    x = float_of_int (i mod cells) *. cell_size;
    y = float_of_int (i / cells) *. cell_size;
    w = cell_size;
    h = cell_size;
  }

let ids = List.init (cells * cells) cell_id
let probes = List.mapi (fun i id -> Solid_color.probe ~id (box i)) ids

type t = Wire.rgb list

let read m =
  let means =
    List.filter_map
      (fun id ->
        Option.map
          (fun (s : Solid_color.stats) -> s.mean)
          (Solid_color.read m id))
      ids
  in
  if List.length means = List.length ids then Some means else None

let moved (a : Wire.rgb) (b : Wire.rgb) =
  Float.abs (a.r -. b.r) +. Float.abs (a.g -. b.g) +. Float.abs (a.b -. b.b)

let change a b =
  List.fold_left2 (fun sum x y -> sum +. moved x y) 0. a b
  /. float_of_int (List.length a)

let min_scene_change = 40.

let left ~before m =
  match read m with
  | Some now -> change before now > min_scene_change
  | None -> false
