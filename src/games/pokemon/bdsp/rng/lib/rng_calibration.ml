type adjustment = Neutral | Raised | Lowered

(* Natures come in rows of five: [nature / 5] is the raised stat and
   [nature mod 5] the lowered one, in [nature_stats] order. *)
let nature_count = 25
let nature_stats = 5

(* Hardy, Docile, Serious, Bashful and Quirky raise and lower the same stat. *)
let row_adjustment ~raised ~lowered stat_index =
  if raised = lowered then Neutral
  else if stat_index = raised then Raised
  else if stat_index = lowered then Lowered
  else Neutral

let nature_adjustment ~nature ~stat_index =
  if nature < 0 || nature >= nature_count || stat_index >= nature_stats then
    Neutral
  else
    row_adjustment ~raised:(nature / nature_stats)
      ~lowered:(nature mod nature_stats) stat_index

type 'a per_stat = {
  hp : 'a;
  attack : 'a;
  defense : 'a;
  spatk : 'a;
  spdef : 'a;
  speed : 'a;
}

(* The C++ formulas run in [uint16_t]; each step wraps as it does there. *)
let uint16_mask = 0xFFFF
let int16_limit = 0x8000
let uint16 value = value land uint16_mask

let int16 value =
  if value >= int16_limit then value - (uint16_mask + 1) else value

let percent = 100
let ev_divisor = 4
let hp_bonus = 10
let other_bonus = 5
let raised_percent = 110
let lowered_percent = 90

let base_term ~base ~level ~iv =
  let ev = 0 in
  let stat = uint16 ((2 * base) + iv + (ev / ev_divisor)) in
  uint16 (stat * level) / percent

let calc_stats_hp ~base ~level ~iv =
  uint16 (base_term ~base ~level ~iv + level + hp_bonus)

let calc_stats_nonhp ~base ~level ~iv adjustment =
  let stat = uint16 (base_term ~base ~level ~iv + other_bonus) in
  match adjustment with
  | Neutral -> stat
  | Raised -> uint16 (stat * raised_percent) / percent
  | Lowered -> uint16 (stat * lowered_percent) / percent

(* Indices into the nature table for each stat. *)
let nature_index_attack = 0
let nature_index_defense = 1
let nature_index_speed = 2
let nature_index_spatk = 3
let nature_index_spdef = 4

let expected_stats (generated : Static_encounter.pokemon) ~base_stats ~level =
  let ivs = generated.ivs in
  let other base iv stat_index =
    int16
      (calc_stats_nonhp ~base ~level ~iv
         (nature_adjustment ~nature:generated.nature ~stat_index))
  in
  {
    hp = int16 (calc_stats_hp ~base:base_stats.hp ~level ~iv:ivs.hp);
    attack = other base_stats.attack ivs.attack nature_index_attack;
    defense = other base_stats.defense ivs.defense nature_index_defense;
    spatk = other base_stats.spatk ivs.spatk nature_index_spatk;
    spdef = other base_stats.spdef ivs.spdef nature_index_spdef;
    speed = other base_stats.speed ivs.speed nature_index_speed;
  }

type starter = Turtwig | Chimchar | Piplup

let starter_base_stats = function
  | Turtwig ->
      { hp = 55; attack = 68; defense = 64; spatk = 45; spdef = 55; speed = 31 }
  | Chimchar ->
      { hp = 44; attack = 58; defense = 44; spatk = 58; spdef = 44; speed = 61 }
  | Piplup ->
      { hp = 53; attack = 51; defense = 53; spatk = 61; spdef = 56; speed = 40 }

type observed = {
  nature : int option;
  gender : Static_encounter.gender option;
  shiny : bool option;
  stats : int option per_stat;
  base_stats : int per_stat;
  level : int;
}

(* A reading that was not taken rules nothing out. *)
let fits observed expected =
  match observed with None -> true | Some value -> value = expected

let stats_fit (observed : int option per_stat) (expected : int per_stat) =
  fits observed.hp expected.hp
  && fits observed.attack expected.attack
  && fits observed.defense expected.defense
  && fits observed.spatk expected.spatk
  && fits observed.spdef expected.spdef
  && fits observed.speed expected.speed

let consistent_with (generated : Static_encounter.pokemon) observed =
  fits observed.nature generated.nature
  && fits observed.gender generated.gender
  && fits observed.shiny (generated.shiny <> Static_encounter.Not_shiny)
  && stats_fit observed.stats
       (expected_stats generated ~base_stats:observed.base_stats
          ~level:observed.level)

type hit = { advance : int; offset : int }
type miss = { candidates : int; reason : string }

let no_candidate_reason ~radius ~intended_advance =
  Printf.sprintf
    "no advance within %d of %d produces that Pokemon. Either the recovered \
     state was wrong, or the press missed by more than the search covered."
    radius intended_advance

let several_candidates_reason (matches : Static_encounter.hit list) =
  Printf.sprintf
    "%d advances fit what was read (%s), so which one was hit cannot be told \
     apart here."
    (List.length matches)
    (String.concat ", "
       (List.map
          (fun (m : Static_encounter.hit) -> string_of_int m.advances)
          matches))

let identify_hit_advance state template ~intended_advance ~radius observed =
  let first =
    if intended_advance > radius then intended_advance - radius else 0
  in
  let searcher =
    Static_encounter.searcher state template ~tsv:0 ~synchronize_nature:None
  in
  let matches =
    Static_encounter.scan searcher ~min_advances:first
      ~max_advances:(intended_advance + radius) ~accept:(fun candidate ->
        consistent_with candidate observed)
  in
  match matches with
  | [] ->
      Error
        {
          candidates = 0;
          reason = no_candidate_reason ~radius ~intended_advance;
        }
  | [ only ] ->
      Ok { advance = only.advances; offset = only.advances - intended_advance }
  | several ->
      Error
        {
          candidates = List.length several;
          reason = several_candidates_reason several;
        }

let advances_between ~from ~to_ ~search_max =
  let rng = Xorshift128.create from in
  let rec walk steps =
    if steps > search_max then None
    else if Xorshift128.state rng = to_ then Some steps
    else (
      ignore (Xorshift128.next rng);
      walk (steps + 1))
  in
  walk 0
