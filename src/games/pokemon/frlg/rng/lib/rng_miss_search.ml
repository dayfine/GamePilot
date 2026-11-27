(* Port of get_search_results and calibration delta logic from
   PokemonFRLG/Programs/RngManipulation/PokemonFRLG_RngCalibration.cpp. *)

type gender = Male | Female | Genderless | Unknown

type stats = Base_stats.stats = {
  hp : int;
  atk : int;
  def : int;
  spa : int;
  spd : int;
  spe : int;
}

type observation = {
  nature : int option;
  gender : gender;
  level : int;
  stats : stats option;
}

type hit = {
  seed_index : int;
  seed : int;
  delay_ms : int;
  advance : int;
  pid : int32;
  seed_delta_frames : int;
  delay_delta_ms : int;
  advance_delta : int;
}

let default_seed_radius = 15
let default_advances_radius = 256
let max_advances_radius = 1024
let seed_distance_weight = 5

let find_seed_index ~delays ~seeds ~seed ~table_delay_ms =
  let n = min (Array.length delays) (Array.length seeds) in
  let rec exact i =
    if i >= n then None
    else if seeds.(i) = seed && delays.(i) = table_delay_ms then Some i
    else exact (i + 1)
  in
  let rec by_seed i =
    if i >= n then None else if seeds.(i) = seed then Some i else by_seed (i + 1)
  in
  match exact 0 with Some _ as hit -> hit | None -> by_seed 0

let gender_matches ~(obs : gender) (actual : Base_stats.gender) =
  match (obs, actual) with
  | Unknown, _ -> true
  | Male, Male | Female, Female | Genderless, Genderless -> true
  | _ -> false

let stats_equal (a : stats) (b : stats) =
  a.hp = b.hp && a.atk = b.atk && a.def = b.def && a.spa = b.spa
  && a.spd = b.spd && a.spe = b.spe

let stats_match ~(base_stats : Base_stats.entry) (obs : observation)
    (p : Pokemon_generation.result) =
  match obs.stats with
  | None -> true
  | Some expected ->
      let computed =
        Base_stats.compute_stats ~base:base_stats.base ~nature:p.nature
          ~ivs:p.ivs ~level:obs.level
      in
      stats_equal expected computed

let matches_observation ~(base_stats : Base_stats.entry) (obs : observation)
    (p : Pokemon_generation.result) =
  let nature_ok =
    match obs.nature with None -> true | Some n -> p.nature = n
  in
  let actual_gender =
    Base_stats.gender_of_pid ~pid:p.pid
      ~gender_threshold:base_stats.gender_threshold
  in
  nature_ok
  && gender_matches ~obs:obs.gender actual_gender
  && stats_match ~base_stats obs p

let make_hit ~target_seed_index ~target_delay_ms ~target_advance ~seed_index
    ~seed ~delay_ms (state : Rng_state.t) (p : Pokemon_generation.result) =
  {
    seed_index;
    seed;
    delay_ms;
    advance = state.advance;
    pid = Int32.of_int p.pid;
    seed_delta_frames = seed_index - target_seed_index;
    delay_delta_ms = delay_ms - target_delay_ms;
    advance_delta = state.advance - target_advance;
  }

let check_state ~base_stats ~target_seed_index ~target_delay_ms ~target_advance
    ~seed_index ~seed ~delay_ms obs state acc =
  let p = Pokemon_generation.pokemon_of_state state in
  if not (matches_observation ~base_stats obs p) then acc
  else
    make_hit ~target_seed_index ~target_delay_ms ~target_advance ~seed_index
      ~seed ~delay_ms state p
    :: acc

let search_seed_row ~base_stats ~target_seed_index ~target_delay_ms
    ~target_advance ~min_adv ~max_adv ~seed_index ~seed ~delay_ms obs acc =
  let step =
    check_state ~base_stats ~target_seed_index ~target_delay_ms ~target_advance
      ~seed_index ~seed ~delay_ms obs
  in
  let rec walk (state : Rng_state.t) acc =
    if state.advance > max_adv then acc
    else walk (Rng_state.next state) (step state acc)
  in
  walk (Rng_state.of_seed ~seed ~advance:min_adv Method1) acc

let hit_distance (h : hit) =
  (abs h.seed_delta_frames * seed_distance_weight) + abs h.advance_delta

let compare_tie a b =
  let s = Int.compare (abs a.seed_delta_frames) (abs b.seed_delta_frames) in
  if s <> 0 then s else Int.compare (abs a.advance_delta) (abs b.advance_delta)

let compare_hits a b =
  let d = Int.compare (hit_distance a) (hit_distance b) in
  if d <> 0 then d else compare_tie a b

let rec fold_seed_rows ~base_stats ~delays ~seeds ~target_seed_index
    ~target_delay_ms ~target_advance ~min_adv ~max_adv ~hi_seed obs i acc =
  if i > hi_seed then acc
  else
    let acc =
      search_seed_row ~base_stats ~target_seed_index ~target_delay_ms
        ~target_advance ~min_adv ~max_adv ~seed_index:i ~seed:seeds.(i)
        ~delay_ms:delays.(i) obs acc
    in
    fold_seed_rows ~base_stats ~delays ~seeds ~target_seed_index
      ~target_delay_ms ~target_advance ~min_adv ~max_adv ~hi_seed obs (i + 1)
      acc

let search_window ~base_stats ~delays ~seeds ~target_seed_index ~target_advance
    ~seed_radius ~adv_radius obs =
  let n = min (Array.length delays) (Array.length seeds) in
  if target_seed_index < 0 || target_seed_index >= n then []
  else
    let target_delay_ms = delays.(target_seed_index) in
    let lo_seed = max 0 (target_seed_index - seed_radius) in
    let hi_seed = min (n - 1) (target_seed_index + seed_radius) in
    let min_adv = max 0 (target_advance - adv_radius) in
    let max_adv = target_advance + adv_radius in
    fold_seed_rows ~base_stats ~delays ~seeds ~target_seed_index
      ~target_delay_ms ~target_advance ~min_adv ~max_adv ~hi_seed obs lo_seed []
    |> List.sort compare_hits

let search_method1 ~base_stats ~delays ~seeds ~target_seed_index ~target_advance
    ?(seed_radius = default_seed_radius)
    ?(advances_radius = default_advances_radius) obs =
  let rec expand adv_radius =
    let hits =
      search_window ~base_stats ~delays ~seeds ~target_seed_index
        ~target_advance ~seed_radius ~adv_radius obs
    in
    if hits <> [] || adv_radius >= max_advances_radius then hits
    else expand (min max_advances_radius (adv_radius * 2))
  in
  expand (max 0 advances_radius)

let gender_to_string = function
  | Male -> "Male"
  | Female -> "Female"
  | Genderless -> "Genderless"
  | Unknown -> "Unknown"

let format_observation (obs : observation) =
  let nature =
    match obs.nature with
    | None -> "Unknown"
    | Some n -> Option.value (Base_stats.nature_name n) ~default:"Unknown"
  in
  let stats =
    match obs.stats with
    | None -> ""
    | Some s ->
        Printf.sprintf " (%d/%d/%d/%d/%d/%d)" s.hp s.atk s.def s.spa s.spd s.spe
  in
  Printf.sprintf "%s %s Lv%d%s" nature
    (gender_to_string obs.gender)
    obs.level stats

let match_count_label total =
  if total = 1 then "1 match" else Printf.sprintf "%d matches" total

let format_hit_report h total =
  Printf.sprintf
    "RNG miss: hit seed %04X (%+d frames / %+d ms), advance %d (%+d adv) [%s]"
    h.seed h.seed_delta_frames h.delay_delta_ms h.advance h.advance_delta
    (match_count_label total)

let format_miss_report ~target_seed ~target_delay_ms ~target_advance = function
  | [] ->
      Printf.sprintf
        "RNG miss: no match near seed %04X (%d ms) advance %d within +/-%d \
         seeds, +/-%d advances"
        target_seed target_delay_ms target_advance default_seed_radius
        max_advances_radius
  | h :: rest -> format_hit_report h (1 + List.length rest)

let calibration_delta_of_hit (h : hit) = (-h.delay_delta_ms, -h.advance_delta)
