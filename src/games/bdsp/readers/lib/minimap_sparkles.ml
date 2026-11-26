module PB = Switch_home.Picture_box
module CS = Switch_home.Color_share

type corridor = Bottom_east | East_vertical | Top_east
type target = { corridor : corridor; bucket : int }

type nearby = {
  bottom_east : bool;
  east_vertical : bool;
  top_east : bool;
  targets : target list;
  player : target option;
}

let buckets_per_corridor = 4

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
let be_x0 = 0.114
let be_w = 0.032
let be_y = 0.138
let be_h = 0.022
let ev_x = 0.128
let ev_w = 0.022
let ev_y_top = 0.082
let ev_h = 0.056
let te_x_left = 0.100
let te_w = 0.048
let te_y = 0.055
let te_h = 0.027

(* Full-sized Underground map (Y -> A) SW green ring bounds from run-55/000004.jpg:
   bottom_east:   x=0.415..0.450, y=0.785..0.810
   east_vertical: x=0.438..0.455, y=0.700..0.785
   top_east:      x=0.415..0.450, y=0.685..0.708 *)
let fm_be_x0 = 0.415
let fm_be_w = 0.035
let fm_be_y = 0.785
let fm_be_h = 0.025
let fm_ev_x = 0.438
let fm_ev_w = 0.017
let fm_ev_y_top = 0.700
let fm_ev_h = 0.085
let fm_te_x_left = 0.415
let fm_te_w = 0.035
let fm_te_y = 0.685
let fm_te_h = 0.023
let fm_min_sparkle_share = 0.004
let orange_r_min = 200
let orange_g_min = 110
let orange_b_min = 0
let orange_r_max = 255
let orange_g_max = 215
let orange_b_max = 80
let orange_min = (orange_r_min, orange_g_min, orange_b_min)
let orange_max = (orange_r_max, orange_g_max, orange_b_max)
let pink_r_min = 185
let pink_g_min = 80
let pink_b_min = 100
let pink_r_max = 255
let pink_g_max = 185
let pink_b_max = 190
let pink_min = (pink_r_min, pink_g_min, pink_b_min)
let pink_max = (pink_r_max, pink_g_max, pink_b_max)
let min_sparkle_share = 0.008
let min_player_share = 0.010

let corridor_name = function
  | Bottom_east -> "bottom_east"
  | East_vertical -> "east_vertical"
  | Top_east -> "top_east"

let sparkle_id c i = Printf.sprintf "bdsp_mm_sp_%s_%d" (corridor_name c) i
let full_map_id c i = Printf.sprintf "bdsp_fm_sp_%s_%d" (corridor_name c) i
let player_id c i = Printf.sprintf "bdsp_mm_pl_%s_%d" (corridor_name c) i

let full_map_bucket_box c i : Wire.box =
  let n = float_of_int buckets_per_corridor in
  let fi = float_of_int i in
  match c with
  | Bottom_east ->
      let bw = fm_be_w /. n in
      { x = fm_be_x0 +. (fi *. bw); y = fm_be_y; w = bw; h = fm_be_h }
  | East_vertical ->
      let bh = fm_ev_h /. n in
      let y = fm_ev_y_top +. ((n -. 1. -. fi) *. bh) in
      { x = fm_ev_x; y; w = fm_ev_w; h = bh }
  | Top_east ->
      let bw = fm_te_w /. n in
      let x = fm_te_x_left +. ((n -. 1. -. fi) *. bw) in
      { x; y = fm_te_y; w = bw; h = fm_te_h }

let bucket_box c i : Wire.box =
  let n = float_of_int buckets_per_corridor in
  let fi = float_of_int i in
  match c with
  | Bottom_east ->
      let bw = be_w /. n in
      { x = be_x0 +. (fi *. bw); y = be_y; w = bw; h = be_h }
  | East_vertical ->
      let bh = ev_h /. n in
      let y = ev_y_top +. ((n -. 1. -. fi) *. bh) in
      { x = ev_x; y; w = ev_w; h = bh }
  | Top_east ->
      let bw = te_w /. n in
      let x = te_x_left +. ((n -. 1. -. fi) *. bw) in
      { x; y = te_y; w = bw; h = te_h }

let all_buckets =
  let corridors = [ Bottom_east; East_vertical; Top_east ] in
  List.concat_map
    (fun corridor ->
      List.init buckets_per_corridor (fun bucket -> { corridor; bucket }))
    corridors

let make_probe ~picture ~id ~min ~max box =
  Option.map
    (fun box -> Wire.color_count_probe ~id ~box ~min ~max ~delivery:Every)
    (PB.clipped ~picture box)

let bucket_probes ~picture { corridor; bucket } =
  let box = bucket_box corridor bucket in
  List.filter_map Fun.id
    [
      make_probe ~picture
        ~id:(sparkle_id corridor bucket)
        ~min:orange_min ~max:orange_max box;
      make_probe ~picture
        ~id:(player_id corridor bucket)
        ~min:pink_min ~max:pink_max box;
    ]

let probes ~picture = List.concat_map (bucket_probes ~picture) all_buckets

let full_map_probes ~picture =
  List.filter_map
    (fun { corridor; bucket } ->
      make_probe ~picture
        ~id:(full_map_id corridor bucket)
        ~min:orange_min ~max:orange_max
        (full_map_bucket_box corridor bucket))
    all_buckets

let share_of m id = Option.value (CS.read m id) ~default:0.

(* Merge runs of adjacent active buckets within the same corridor into a single
   peak waypoint so one straddling diamond never generates two stops. *)
let flush_peak run acc =
  match run with
  | [] -> acc
  | first :: rest ->
      let peak, _ =
        List.fold_left
          (fun (bt, bs) (t, s) -> if s > bs then (t, s) else (bt, bs))
          first rest
      in
      peak :: acc

let continues_run run t =
  match run with
  | (prev, _) :: _ -> prev.corridor = t.corridor && t.bucket = prev.bucket + 1
  | [] -> false

let rec merge_loop run acc = function
  | [] -> List.rev (flush_peak run acc)
  | ((t, _) as item) :: rest ->
      if continues_run run t then merge_loop (item :: run) acc rest
      else merge_loop [ item ] (flush_peak run acc) rest

let merge_adjacent_peaks scored = merge_loop [] [] scored

let read_targets ~id_of ~threshold m =
  all_buckets
  |> List.filter_map (fun t ->
         let s = share_of m (id_of t.corridor t.bucket) in
         if s >= threshold then Some (t, s) else None)
  |> merge_adjacent_peaks

let read_player m =
  let best =
    List.fold_left
      (fun acc t ->
        let s = share_of m (player_id t.corridor t.bucket) in
        match acc with
        | None when s >= min_player_share -> Some (t, s)
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
  let targets = read_targets ~id_of:sparkle_id ~threshold:min_sparkle_share m in
  nearby_of ~targets ~player:(read_player m)

let read_full_map m =
  let targets =
    read_targets ~id_of:full_map_id ~threshold:fm_min_sparkle_share m
  in
  nearby_of ~targets ~player:None

let any n = n.targets <> []
let target_str t = Printf.sprintf "%s[%d]" (corridor_name t.corridor) t.bucket

let to_string n =
  match n.targets with
  | [] -> "none"
  | xs -> String.concat ", " (List.map target_str xs)
