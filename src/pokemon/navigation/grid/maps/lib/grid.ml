type 'a t = { width : int; height : int; cells : 'a array }

let index grid ({ x; y } : Tile_pos.t) = (y * grid.width) + x

let init ~width ~height f =
  if width < 0 || height < 0 then invalid_arg "Grid.init: negative size";
  let at i = f { Tile_pos.x = i mod width; y = i / width } in
  { width; height; cells = Array.init (width * height) at }

let width grid = grid.width
let height grid = grid.height

let contains grid ({ x; y } : Tile_pos.t) =
  0 <= x && x < grid.width && 0 <= y && y < grid.height

let find grid pos =
  if contains grid pos then Some grid.cells.(index grid pos) else None

let off_grid what pos =
  invalid_arg
    (Printf.sprintf "Grid.%s: %s is off the grid" what (Tile_pos.to_string pos))

let get grid pos =
  if contains grid pos then grid.cells.(index grid pos) else off_grid "get" pos

let set grid pos value =
  if not (contains grid pos) then off_grid "set" pos;
  let cells = Array.copy grid.cells in
  cells.(index grid pos) <- value;
  { grid with cells }

let positions grid =
  List.init (grid.width * grid.height) (fun i ->
      { Tile_pos.x = i mod grid.width; y = i / grid.width })
