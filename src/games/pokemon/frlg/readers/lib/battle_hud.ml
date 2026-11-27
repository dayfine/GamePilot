type foe_status = Healthy | Asleep | Paralyzed | Other_status

type hp_bar_layout = {
  prefix : string;
  x : float;
  y : float;
  w : float;
  h : float;
  segments : int;
}

type hp_thresholds = {
  min_chroma : float;
  min_brightness : float;
  max_stddev_sum : float;
}

type status_thresholds = {
  healthy_min_sum : float;
  healthy_max_chroma : float;
  sleep_min_sum : float;
  sleep_max_sum : float;
  sleep_max_chroma : float;
  par_min_chroma : float;
  par_min_r_share : float;
  par_min_g_share : float;
  par_max_b_share : float;
}

(* GBA 240x160 singles healthbox coordinates (pokefirered battle_interface.c):
   foe 48px HP bar at x 52..100, y 33..36; player 48px HP bar at x 176..224,
   y 90..93; foe 20x8 status icon at x 16..36, y 31..39. *)
let foe_bar : hp_bar_layout =
  {
    prefix = "battle.hud.foe_hp.";
    x = 52.;
    y = 33.;
    w = 48.;
    h = 3.;
    segments = 12;
  }

let player_bar : hp_bar_layout =
  {
    prefix = "battle.hud.player_hp.";
    x = 176.;
    y = 90.;
    w = 48.;
    h = 3.;
    segments = 12;
  }

let status_probe_id = "battle.hud.foe_status"
let status_box = Game_pixels.box { x = 16.; y = 31.; w = 20.; h = 8. }

let hp_thresh : hp_thresholds =
  { min_chroma = 35.; min_brightness = 115.; max_stddev_sum = 120. }

let status_thresh : status_thresholds =
  {
    healthy_min_sum = 560.;
    healthy_max_chroma = 65.;
    sleep_min_sum = 260.;
    sleep_max_sum = 550.;
    sleep_max_chroma = 35.;
    par_min_chroma = 40.;
    par_min_r_share = 0.38;
    par_min_g_share = 0.34;
    par_max_b_share = 0.25;
  }

let seg_id bar idx = Printf.sprintf "%s%d" bar.prefix idx

let segment_probe bar seg_w idx =
  let x = bar.x +. (float_of_int idx *. seg_w) in
  let box = Game_pixels.box { x; y = bar.y; w = seg_w; h = bar.h } in
  Solid_color.probe ~id:(seg_id bar idx) box

let bar_probes bar =
  let seg_w = bar.w /. float_of_int bar.segments in
  List.init bar.segments (segment_probe bar seg_w)

let probes =
  bar_probes foe_bar @ bar_probes player_bar
  @ [ Solid_color.probe ~id:status_probe_id status_box ]

let rgb_chroma (c : Wire.rgb) =
  let max_c = Float.max c.r (Float.max c.g c.b) in
  let min_c = Float.min c.r (Float.min c.g c.b) in
  (max_c, max_c -. min_c)

let is_filled_hp_segment (s : Solid_color.stats) =
  let max_c, chroma = rgb_chroma s.mean in
  chroma >= hp_thresh.min_chroma
  && max_c >= hp_thresh.min_brightness
  && Solid_color.sum s.stddev <= hp_thresh.max_stddev_sum

let read_hp_bar m bar =
  let rec loop idx seen filled =
    if idx >= bar.segments then
      if seen = 0 then None
      else Some (float_of_int filled /. float_of_int bar.segments)
    else
      match Solid_color.read m (seg_id bar idx) with
      | None -> loop (idx + 1) seen filled
      | Some s ->
          let filled = if is_filled_hp_segment s then filled + 1 else filled in
          loop (idx + 1) (seen + 1) filled
  in
  loop 0 0 0

let foe_hp_ratio m =
  if Battle_screen.foe_box m then read_hp_bar m foe_bar else None

let player_hp_ratio m =
  if Battle_screen.player_box m then read_hp_bar m player_bar else None

let is_paralyzed (mean : Wire.rgb) ~avg_sum ~chroma =
  avg_sum > 0.
  && chroma >= status_thresh.par_min_chroma
  && mean.r /. avg_sum >= status_thresh.par_min_r_share
  && mean.g /. avg_sum >= status_thresh.par_min_g_share
  && mean.b /. avg_sum <= status_thresh.par_max_b_share

let classify_status_stats (s : Solid_color.stats) =
  let avg_sum = Solid_color.sum s.mean in
  let _, chroma = rgb_chroma s.mean in
  if
    avg_sum >= status_thresh.healthy_min_sum
    && chroma <= status_thresh.healthy_max_chroma
  then Healthy
  else if
    avg_sum >= status_thresh.sleep_min_sum
    && avg_sum <= status_thresh.sleep_max_sum
    && chroma <= status_thresh.sleep_max_chroma
  then Asleep
  else if is_paralyzed s.mean ~avg_sum ~chroma then Paralyzed
  else Other_status

let foe_status m =
  if not (Battle_screen.foe_box m) then None
  else Option.map classify_status_stats (Solid_color.read m status_probe_id)

let foe_asleep m = Option.map (fun st -> st = Asleep) (foe_status m)
