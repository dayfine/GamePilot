(* Port of the static and wild searches (Pokemon/Pokemon_AdvRng.cpp). *)

module G = Pokemon_generation

type iv_range = { low : int; high : int }

type iv_ranges = {
  hp : iv_range;
  attack : iv_range;
  defense : iv_range;
  spatk : iv_range;
  spdef : iv_range;
  speed : iv_range;
}

type filters = {
  species : string;
  level : int;
  gender : G.gender option;
  nature : int option;
  ability : int option;
  ivs : iv_ranges;
  shiny : G.shiny_type option;
  rng_method : Rng_state.rng_method;
}

type trainer = { gender_threshold : int; tid_xor_sid : int }

let any_or wanted actual =
  match wanted with None -> true | Some w -> w = actual

let in_range r iv = r.low <= iv && r.high >= iv

let ivs_in (r : iv_ranges) (ivs : G.ivs) =
  in_range r.hp ivs.hp
  && in_range r.attack ivs.attack
  && in_range r.defense ivs.defense
  && in_range r.spatk ivs.spatk && in_range r.spdef ivs.spdef
  && in_range r.speed ivs.speed

(* A genderless result (None) never equals a wanted gender. *)
let gender_matches wanted trainer (res : G.result) =
  match wanted with
  | None -> true
  | Some _ ->
      G.gender_of_value res.gender_value ~threshold:trainer.gender_threshold
      = wanted

let matches f trainer (res : G.result) =
  any_or f.nature res.nature
  && any_or f.ability res.ability
  && gender_matches f.gender trainer res
  && any_or f.shiny
       (G.shiny_type_of_pid res.pid ~tid_xor_sid:trainer.tid_xor_sid)
  && ivs_in f.ivs res.ivs

let matches_wild f trainer (res : Wild_encounter.result) =
  Wild_encounter.species_matches ~observed:f.species ~candidate:res.species
  && f.level = res.level
  && matches f trainer res.pokemon

(* search_advance_range: each allowed method, advances min..max inclusive. *)
let search_advance_range f ~keep ~seed ~min_advance ~max_advance =
  let allowed m = f.rng_method = Any || f.rng_method = m in
  let rec walk state hits =
    if state.Rng_state.advance > max_advance then hits
    else
      walk (Rng_state.next state) (if keep state then state :: hits else hits)
  in
  List.filter allowed [ Rng_state.Method1; Method2; Method4 ]
  |> List.concat_map (fun m ->
         List.rev (walk (Rng_state.of_seed ~seed ~advance:min_advance m) []))

let search ~keep f ~seeds ~min_advance ~max_advance =
  List.concat_map
    (fun seed -> search_advance_range f ~keep ~seed ~min_advance ~max_advance)
    seeds

let search_static ?roaming f trainer =
  search f ~keep:(fun state ->
      matches f trainer (G.pokemon_of_state ?roaming state))

let search_wild f trainer slots ~super_rod =
  search f ~keep:(fun state ->
      matches_wild f trainer
        (Wild_encounter.pokemon_of_state state slots ~super_rod))
