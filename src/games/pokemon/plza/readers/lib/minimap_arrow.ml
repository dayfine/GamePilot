let box =
  Native_box.of_fractions
    { left = 0.076; top = 0.138; width = 0.031; height = 0.062 }

(* OpenCV's cyan, hue 90 to 110 (of 180) with saturation and value over 200,
   where blue is the largest channel and red the smallest: blue 200 or more,
   at least green, 41 r - 60 g + 19 b under 0 (hue under 221 degrees), and
   111 b - 510 r at least 0 (saturation over 199.5 of 255). *)
(* 41 r - 60 g + 19 b under 0: hue under 221 degrees, blue the largest
   channel and red the smallest. *)
let hue_red = -41
let hue_green = 60
let hue_blue = -19
let hue_under_221 = (hue_red, hue_green, hue_blue)

(* 111 b - 510 r at least 0: saturation over 199.5 of 255, red the smallest. *)
let saturation_red = -510
let saturation_blue = 111
let saturation_200 = (saturation_red, 0, saturation_blue)

let cyan =
  Wire.Line_shares.
    [
      { weights = (0, 0, 1); op = Greater_equal; value = 200 };
      { weights = (0, -1, 1); op = Greater_equal; value = 0 };
      { weights = hue_under_221; op = Greater; value = 0 };
      { weights = saturation_200; op = Greater_equal; value = 0 };
    ]

let id row = Printf.sprintf "minimap_arrow.%d" row

let row_probe ~picture row =
  Pixel_shares.probe ~picture ~id:(id row)
    { box with y = box.y + row; h = 1 }
    cyan

let probes ~picture = List.concat (List.init box.h (row_probe ~picture))

(* The arrow's area at 1080p. *)
let min_area = 250
let max_area = 350
let half = 0.5

type point = { x : int; y : int }

(* The 4-connected blob of [start] in [mask], marking [seen]. *)
let blob mask seen start =
  let rows = Array.length mask and cols = Array.length mask.(0) in
  let inside p = p.y >= 0 && p.y < rows && p.x >= 0 && p.x < cols in
  let rec grow acc = function
    | [] -> acc
    | p :: rest when inside p && mask.(p.y).(p.x) && not seen.(p.y).(p.x) ->
        seen.(p.y).(p.x) <- true;
        grow (p :: acc)
          ({ p with x = p.x + 1 }
          :: { p with x = p.x - 1 }
          :: { p with y = p.y + 1 }
          :: { p with y = p.y - 1 }
          :: rest)
    | _ :: rest -> grow acc rest
  in
  grow [] [ start ]

let all_points rows cols =
  List.concat (List.init rows (fun y -> List.init cols (fun x -> { x; y })))

(* The largest blob; the first found of equals, as the fork's scan. *)
let largest mask =
  let rows = Array.length mask and cols = Array.length mask.(0) in
  let seen = Array.make_matrix rows cols false in
  List.fold_left
    (fun best p ->
      let b = blob mask seen p in
      if List.length b > List.length best then b else best)
    [] (all_points rows cols)

let cross o a b = ((a.x - o.x) * (b.y - o.y)) - ((a.y - o.y) * (b.x - o.x))

(* Andrew's monotone chain: the hull counter-clockwise (in image axes),
   without collinear points. *)
let half_hull points =
  List.fold_left
    (fun acc p ->
      let rec pop = function
        | b :: a :: rest when cross a b p <= 0 -> pop (a :: rest)
        | h -> h
      in
      p :: pop acc)
    [] points

let hull points =
  let sorted = List.sort_uniq compare (List.map (fun p -> (p.x, p.y)) points) in
  let sorted = List.map (fun (x, y) -> { x; y }) sorted in
  let lower = half_hull sorted and upper = half_hull (List.rev sorted) in
  List.rev (List.tl lower) @ List.rev (List.tl upper)

(* Inside the hull or on its edge. *)
let in_hull hull p =
  match hull with
  | [] | [ _ ] -> false
  | first :: _ ->
      let rec edges = function
        | a :: (b :: _ as rest) -> cross a b p >= 0 && edges rest
        | [ last ] -> cross last first p >= 0
        | [] -> true
      in
      edges hull

let centre points =
  let n = float_of_int (List.length points) in
  let sum f = List.fold_left (fun s p -> s +. float_of_int (f p)) 0. points in
  (sum (fun p -> p.x) /. n, sum (fun p -> p.y) /. n)

let min_length = 0.001
let half_turn = 180.
let degrees_per_radian = half_turn /. Float.pi
let quarter_turn = 90.
let full_turn = 360.

let bearing (cx, cy) furthest =
  let dx = float_of_int furthest.x -. cx
  and dy = float_of_int furthest.y -. cy in
  let a = (Float.atan2 dy dx *. degrees_per_radian) +. quarter_turn in
  Float.rem (a +. full_turn) full_turn

(* The blob pixel furthest along [(ux, uy)] from the centre; the first of
   equals. *)
let furthest (cx, cy) (ux, uy) points =
  let along p =
    ((float_of_int p.x -. cx) *. ux) +. ((float_of_int p.y -. cy) *. uy)
  in
  List.fold_left
    (fun best p ->
      match best with Some b when along p <= along b -> best | _ -> Some p)
    None points

let direction (cx, cy) notch =
  let n = float_of_int (List.length notch) in
  let mean f =
    List.fold_left (fun s p -> s +. float_of_int (f p)) 0. notch /. n
  in
  let vx = cx -. mean (fun p -> p.x) and vy = cy -. mean (fun p -> p.y) in
  let length = Float.sqrt ((vx *. vx) +. (vy *. vy)) in
  if length < min_length then None else Some (vx /. length, vy /. length)

let of_blob mask arrow =
  let rows = Array.length mask and cols = Array.length mask.(0) in
  let h = hull arrow in
  let on_arrow = Array.make_matrix rows cols false in
  List.iter (fun p -> on_arrow.(p.y).(p.x) <- true) arrow;
  let notch =
    List.filter
      (fun p -> (not on_arrow.(p.y).(p.x)) && in_hull h p)
      (all_points rows cols)
  in
  let c = centre arrow in
  if notch = [] then None
  else
    Option.bind (direction c notch) (fun u ->
        Option.map (bearing c) (furthest c u arrow))

let of_mask mask =
  let arrow = largest mask in
  let area = List.length arrow in
  if area < min_area || area > max_area then None else of_blob mask arrow

let mask_of_rows mask =
  if Array.length mask = 0 || Array.length mask.(0) = 0 then None
  else of_mask mask

let row_mask m row =
  Option.map
    (fun (t : Wire.Line_shares.t) ->
      Array.of_list (List.map (fun s -> s >= half) t.columns))
    (Pixel_shares.lines m (id row))

let read m =
  let rows = List.init box.h (row_mask m) in
  if List.for_all Option.is_some rows then
    mask_of_rows (Array.of_list (List.filter_map Fun.id rows))
  else None
