type t = Wire.rgb list

let max_change = 2.0
let side = 4

let cells =
  List.init (side * side) (fun i ->
      let f n = float_of_int n /. float_of_int side in
      let size = 1.0 /. float_of_int side in
      ( Printf.sprintf "frame_cells.%d" i,
        Native_box.of_fractions
          {
            left = f (i mod side);
            top = f (i / side);
            width = size;
            height = size;
          } ))

let probes ~picture =
  List.concat_map (fun (id, b) -> Box_color.probe ~picture ~id b) cells

let read m =
  let means =
    List.filter_map
      (fun (id, _) ->
        Option.map (fun (s : Box_color.stats) -> s.mean) (Box_color.read m id))
      cells
  in
  if List.length means = List.length cells then Some means else None

let close (a : Wire.rgb) (b : Wire.rgb) =
  Float.abs (a.r -. b.r) < max_change
  && Float.abs (a.g -. b.g) < max_change
  && Float.abs (a.b -. b.b) < max_change

let same a b = List.length a = List.length b && List.for_all2 close a b
