module PB = Switch.Picture_box
module CS = Switch.Color_share

type corridor = Bottom_east | East_vertical | Top_east
type target = { corridor : corridor; bucket : int }

type nearby = {
  bottom_east : bool;
  east_vertical : bool;
  top_east : bool;
  targets : target list;
  player : target option;
}

type map_layout = {
  bottom_east : Wire.box;
  east_vertical : Wire.box;
  top_east : Wire.box;
}

type rgb = { r : int; g : int; b : int }
type color_range = { min : rgb; max : rgb }

type thresholds = {
  minimap_sparkle : float;
  full_map_sparkle : float;
  player : float;
}

let buckets_per_corridor = 8

let none =
  {
    bottom_east = false;
    east_vertical = false;
    top_east = false;
    targets = [];
    player = None;
  }

(* Measured from run-39/000024.jpg, run-42/000300.jpg, run-46/000025.jpg:
   bottom_east:   x=0.114..0.146 (West->East), y=0.138..0.160
   east_vertical: x=0.128..0.150, y=0.138->0.082 (South->North)
   top_east:      x=0.146->0.100 (East->West), y=0.055..0.082 *)
let minimap_layout : map_layout =
  {
    bottom_east = { x = 0.114; y = 0.138; w = 0.032; h = 0.022 };
    east_vertical = { x = 0.128; y = 0.082; w = 0.022; h = 0.056 };
    top_east = { x = 0.100; y = 0.055; w = 0.048; h = 0.027 };
  }

(* Full-sized Underground map (Y -> A) SW green ring bounds verified across
   Console A captures run-55, run-64, run-68, run-71, run-74:
   bottom_east:   x=0.415..0.450, y=0.785..0.808 (diamonds at y~0.794)
   east_vertical: x=0.439..0.454, y=0.700..0.785 (diamonds at x~0.446)
   top_east:      x=0.415..0.450, y=0.680..0.700 (diamonds at y~0.686) *)
let full_map_layout : map_layout =
  {
    bottom_east = { x = 0.415; y = 0.785; w = 0.035; h = 0.023 };
    east_vertical = { x = 0.439; y = 0.700; w = 0.015; h = 0.085 };
    top_east = { x = 0.415; y = 0.680; w = 0.035; h = 0.020 };
  }

let orange =
  { min = { r = 200; g = 110; b = 0 }; max = { r = 255; g = 215; b = 80 } }

let pink =
  { min = { r = 185; g = 80; b = 100 }; max = { r = 255; g = 185; b = 190 } }

let thresholds =
  { minimap_sparkle = 0.008; full_map_sparkle = 0.015; player = 0.010 }

let corridor_name = function
  | Bottom_east -> "bottom_east"
  | East_vertical -> "east_vertical"
  | Top_east -> "top_east"

let sparkle_id c i = Printf.sprintf "bdsp_mm_sp_%s_%d" (corridor_name c) i
let full_map_id c i = Printf.sprintf "bdsp_fm_sp_%s_%d" (corridor_name c) i
let player_id c i = Printf.sprintf "bdsp_mm_pl_%s_%d" (corridor_name c) i

let layout_bucket_box (l : map_layout) c i : Wire.box =
  let n = float_of_int buckets_per_corridor in
  let fi = float_of_int i in
  match c with
  | Bottom_east ->
      let b = l.bottom_east in
      let bw = b.w /. n in
      { x = b.x +. (fi *. bw); y = b.y; w = bw; h = b.h }
  | East_vertical ->
      let b = l.east_vertical in
      let bh = b.h /. n in
      let y = b.y +. ((n -. 1. -. fi) *. bh) in
      { x = b.x; y; w = b.w; h = bh }
  | Top_east ->
      let b = l.top_east in
      let bw = b.w /. n in
      let x = b.x +. ((n -. 1. -. fi) *. bw) in
      { x; y = b.y; w = bw; h = b.h }

let all_buckets =
  let corridors = [ Bottom_east; East_vertical; Top_east ] in
  List.concat_map
    (fun corridor ->
      List.init buckets_per_corridor (fun bucket -> { corridor; bucket }))
    corridors

let rgb_tuple { r; g; b } = (r, g, b)

let make_probe ~picture ~id (range : color_range) box =
  Option.map
    (fun box ->
      Wire.color_count_probe ~id ~box ~min:(rgb_tuple range.min)
        ~max:(rgb_tuple range.max) ~delivery:Every)
    (PB.clipped ~picture box)

let bucket_probes ~picture { corridor; bucket } =
  let box = layout_bucket_box minimap_layout corridor bucket in
  List.filter_map Fun.id
    [
      make_probe ~picture ~id:(sparkle_id corridor bucket) orange box;
      make_probe ~picture ~id:(player_id corridor bucket) pink box;
    ]

let probes ~picture = List.concat_map (bucket_probes ~picture) all_buckets

let full_map_probes ~picture =
  List.filter_map
    (fun { corridor; bucket } ->
      make_probe ~picture
        ~id:(full_map_id corridor bucket)
        orange
        (layout_bucket_box full_map_layout corridor bucket))
    all_buckets

let share_of m id = Option.value (CS.read m id) ~default:0.

(* Pick local-maximum active buckets within each corridor so a single diamond
   straddling two buckets merges to its peak (leftmost on an exact tie), while
   two distinct diamonds separated by a dip both stay as waypoints. *)
let is_local_peak scores i =
  let s = scores.(i) in
  let left_ok = i = 0 || s > scores.(i - 1) in
  let right_ok = i = Array.length scores - 1 || s >= scores.(i + 1) in
  left_ok && right_ok

let corridor_peaks ~id_of ~threshold m corridor =
  let scores =
    Array.init buckets_per_corridor (fun i -> share_of m (id_of corridor i))
  in
  List.init buckets_per_corridor Fun.id
  |> List.filter_map (fun bucket ->
         if scores.(bucket) >= threshold && is_local_peak scores bucket then
           Some { corridor; bucket }
         else None)

let read_targets ~id_of ~threshold m =
  List.concat_map
    (corridor_peaks ~id_of ~threshold m)
    [ Bottom_east; East_vertical; Top_east ]

let read_player m =
  let best =
    List.fold_left
      (fun acc t ->
        let s = share_of m (player_id t.corridor t.bucket) in
        match acc with
        | None when s >= thresholds.player -> Some (t, s)
        | Some (_, bs) when s > bs -> Some (t, s)
        | _ -> acc)
      None all_buckets
  in
  Option.map fst best

let nearby_of ~targets ~player =
  let has_corr c = List.exists (fun t -> t.corridor = c) targets in
  {
    bottom_east = has_corr Bottom_east;
    east_vertical = has_corr East_vertical;
    top_east = has_corr Top_east;
    targets;
    player;
  }

let read m =
  let targets =
    read_targets ~id_of:sparkle_id ~threshold:thresholds.minimap_sparkle m
  in
  nearby_of ~targets ~player:(read_player m)

let read_full_map m =
  let targets =
    read_targets ~id_of:full_map_id ~threshold:thresholds.full_map_sparkle m
  in
  nearby_of ~targets ~player:None

let debug_corridor m c =
  let parts =
    List.init buckets_per_corridor (fun i ->
        Printf.sprintf "%d:%.4f" i (share_of m (full_map_id c i)))
  in
  Printf.sprintf "%s=[%s]" (corridor_name c) (String.concat " " parts)

let debug_full_map m =
  String.concat " | "
    (List.map (debug_corridor m) [ Bottom_east; East_vertical; Top_east ])

let any n = n.targets <> []
let target_str t = Printf.sprintf "%s[%d]" (corridor_name t.corridor) t.bucket

let to_string n =
  match n.targets with
  | [] -> "none"
  | xs -> String.concat ", " (List.map target_str xs)
