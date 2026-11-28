(* The soonest shiny Method 1 gift target in a seed table. *)

type t = {
  seed : int;
  table_delay_ms : int;
  advance : int;
  pokemon : Pokemon_generation.result;
  timings : Rng_timings.t;
}

let total_ms t = Rng_timings.total_delay_ms t.timings

let is_shiny ~tid_xor_sid (p : Pokemon_generation.result) =
  Pokemon_generation.shiny_type_of_pid p.pid ~tid_xor_sid <> Normal

let timed timing model calibrations ~table_delay_ms ~seed (state : Rng_state.t)
    pokemon =
  timing model ~seed_delay_ms:table_delay_ms ~advances:state.advance
    ~use_teachy_tv:false calibrations
  |> Result.to_option
  |> Option.map (fun timings ->
         { seed; table_delay_ms; advance = state.advance; pokemon; timings })

let sooner a b =
  match (a, b) with
  | None, x | x, None -> x
  | Some x, Some y -> if total_ms y < total_ms x then b else a

let first_hit timing model calibrations ~tid_xor_sid ~max_advance
    ~table_delay_ms ~seed ~min_advance =
  let rec walk (state : Rng_state.t) =
    if state.advance > max_advance then None
    else
      let pokemon = Pokemon_generation.pokemon_of_state state in
      let hit =
        if is_shiny ~tid_xor_sid pokemon then
          timed timing model calibrations ~table_delay_ms ~seed state pokemon
        else None
      in
      if Option.is_some hit then hit else walk (Rng_state.next state)
  in
  walk (Rng_state.of_seed ~seed ~advance:min_advance Method1)

let find ?(calibrations = Rng_timings.no_calibrations)
    ?(timing = Rng_timings.gift) model ~delays ~seeds ~tid_xor_sid ~min_advance
    ~max_advance =
  let row i =
    first_hit timing model calibrations ~tid_xor_sid ~max_advance
      ~table_delay_ms:delays.(i) ~seed:seeds.(i) ~min_advance
  in
  let rows = min (Array.length delays) (Array.length seeds) in
  List.fold_left
    (fun best i -> sooner best (row i))
    None (List.init rows Fun.id)

let describe t =
  Printf.sprintf "seed %04X at %d ms, advance %d: nature %d, PID %08X" t.seed
    t.table_delay_ms t.advance t.pokemon.nature t.pokemon.pid
