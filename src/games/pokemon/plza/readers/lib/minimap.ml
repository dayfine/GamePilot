(* The minimap's box on 1280x720, as fractions: 132 px square at (52, 55), in
   16 x 16 cells. *)
let cells = 16
let base_width = 1280.
let base_height = 720.
let left_px = 52.
let top_px = 55.
let side_px = 132.
let box_left = left_px /. base_width
let box_top = top_px /. base_height
let box_width = side_px /. base_width
let box_height = side_px /. base_height

(* The ring of cells compared: centres 22 to 62 of the box's 66 px half
   width. *)
let half_width = 66.
let inner_px = 22.
let outer_px = 62.
let ring_inner = inner_px /. half_width
let ring_outer = outer_px /. half_width
let match_max = 30.0
let max_gain = 2.0
let centre i = ((float_of_int i +. 0.5) /. float_of_int cells *. 2.) -. 1.

let in_ring (row, col) =
  let x = centre col and y = centre row in
  let r2 = (x *. x) +. (y *. y) in
  r2 >= ring_inner *. ring_inner && r2 <= ring_outer *. ring_outer

let ring =
  List.init (cells * cells) (fun i -> (i / cells, i mod cells))
  |> List.filter in_ring

let cell_box (row, col) =
  let w = box_width /. float_of_int cells
  and h = box_height /. float_of_int cells in
  Native_box.of_fractions
    {
      left = box_left +. (w *. float_of_int col);
      top = box_top +. (h *. float_of_int row);
      width = w;
      height = h;
    }

let id (row, col) = Printf.sprintf "minimap.%d.%d" row col

let probes ~picture =
  List.concat_map
    (fun cell -> Box_color.probe ~picture ~id:(id cell) (cell_box cell))
    ring

type rgb = { r : float; g : float; b : float }

let channel_digits = 2
let pixel_digits = 3 * channel_digits

let hex_channel row offset =
  Option.map float_of_int
    (int_of_string_opt ("0x" ^ String.sub row offset channel_digits))

let hex_pixel row col =
  let at k = hex_channel row ((col * pixel_digits) + (k * channel_digits)) in
  match (at 0, at 1, at 2) with
  | Some r, Some g, Some b -> Some { r; g; b }
  | _ -> None

let grid_cell rows (row, col) =
  match List.nth_opt rows row with
  | Some hex when String.length hex = cells * pixel_digits -> hex_pixel hex col
  | _ -> None

let all_some xs =
  if List.for_all Option.is_some xs then Some (List.filter_map Fun.id xs)
  else None

let reference_ring rows =
  if List.length rows = cells then all_some (List.map (grid_cell rows) ring)
  else None

let references =
  List.filter_map
    (fun (name, rows) -> Option.map (fun r -> (name, r)) (reference_ring rows))
    Minimap_references.all

let reference_names = List.map fst references

let screen_cell m cell =
  Option.map
    (fun (s : Box_color.stats) -> { r = s.mean.r; g = s.mean.g; b = s.mean.b })
    (Box_color.read m (id cell))

let screen_ring m = all_some (List.map (screen_cell m) ring)
let sum f xs = List.fold_left (fun a x -> a +. f x) 0. xs

let gain want have =
  if have <= 0. then 1.
  else Float.min max_gain (Float.max (1. /. max_gain) (want /. have))

(* Each channel's mean scaled to the reference's (within max_gain). *)
let gain_matched reference ring =
  let g f = gain (sum f reference) (sum f ring) in
  let gr = g (fun c -> c.r)
  and gg = g (fun c -> c.g)
  and gb = g (fun c -> c.b) in
  List.map (fun c -> { r = c.r *. gr; g = c.g *. gg; b = c.b *. gb }) ring

let rmsd reference ring =
  let sq a b = (a -. b) *. (a -. b) in
  let total =
    List.fold_left2
      (fun acc a b -> acc +. sq a.r b.r +. sq a.g b.g +. sq a.b b.b)
      0. reference ring
  in
  Float.sqrt (total /. float_of_int (List.length ring))

let distances m =
  Option.map
    (fun ring ->
      List.map
        (fun (name, reference) ->
          (name, rmsd reference (gain_matched reference ring)))
        references)
    (screen_ring m)

let nearest ds =
  List.fold_left
    (fun best (name, d) ->
      match best with
      | Some (_, bd) when d >= bd -> best
      | _ when d > match_max -> best
      | _ -> Some (name, d))
    None ds

let read m = Option.bind (distances m) (fun ds -> Option.map fst (nearest ds))
