(* The soonest shiny wild target in a seed table (new: see the .mli). *)

type t = {
  seed : int;
  table_delay_ms : int;
  advance : int;
  encounter : Wild_encounter.result;
  timings : Rng_timings.t;
}

let total_ms t = Rng_timings.total_delay_ms t.timings

let wanted ~species ~tid_xor_sid (e : Wild_encounter.result) =
  Wild_encounter.species_matches ~observed:species ~candidate:e.species
  && Pokemon_generation.shiny_type_of_pid e.pokemon.pid ~tid_xor_sid <> Normal

let timed model calibrations ~table_delay_ms ~seed (state : Rng_state.t)
    encounter =
  Rng_timings.sweet_scent model ~seed_delay_ms:table_delay_ms
    ~advances:state.advance ~use_teachy_tv:false calibrations
  |> Result.to_option
  |> Option.map (fun timings ->
         { seed; table_delay_ms; advance = state.advance; encounter; timings })

let sooner a b =
  match (a, b) with
  | None, x | x, None -> x
  | Some x, Some y -> if total_ms y < total_ms x then b else a

(* The soonest hit of one seed: the first wanted advance whose timings pass. *)
let first_hit model calibrations ~super_rod slots ~species ~tid_xor_sid
    ~max_advance ~table_delay_ms ~seed ~min_advance =
  let rec walk (state : Rng_state.t) =
    if state.advance > max_advance then None
    else
      let e = Wild_encounter.pokemon_of_state state slots ~super_rod in
      let hit =
        if wanted ~species ~tid_xor_sid e then
          timed model calibrations ~table_delay_ms ~seed state e
        else None
      in
      if Option.is_some hit then hit else walk (Rng_state.next state)
  in
  walk (Rng_state.of_seed ~seed ~advance:min_advance Method1)

let find ?(calibrations = Rng_timings.no_calibrations) ?(super_rod = false)
    model ~delays ~seeds slots ~species ~tid_xor_sid ~min_advance ~max_advance =
  let row i =
    first_hit model calibrations ~super_rod slots ~species ~tid_xor_sid
      ~max_advance ~table_delay_ms:delays.(i) ~seed:seeds.(i) ~min_advance
  in
  let rows = min (Array.length delays) (Array.length seeds) in
  List.fold_left
    (fun best i -> sooner best (row i))
    None (List.init rows Fun.id)

let describe t =
  Printf.sprintf "seed %04X at %d ms, advance %d: %s Lv %d, nature %d, PID %08X"
    t.seed t.table_delay_ms t.advance t.encounter.species t.encounter.level
    t.encounter.pokemon.nature t.encounter.pokemon.pid
