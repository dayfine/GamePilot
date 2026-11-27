(* Shared live RNG miss-distance reporting and Switch auto-calibration for
   Gift_rng and Wild_rng. *)

module R = Frlg_rng
module MS = Frlg_rng.Rng_miss_search

type summary_miss = { species : string option; observation : MS.observation }

let skills_page = 2

let miss_gender_of = function
  | Some Frlg_text.Summary_stats.Male -> MS.Male
  | Some Female -> Female
  | Some Genderless -> Genderless
  | None -> Unknown

let miss_stats_of (s : Frlg_text.Summary_stats.stats) : MS.stats =
  { hp = s.hp; atk = s.atk; def = s.def; spa = s.spa; spd = s.spd; spe = s.spe }

let read_page2_stats glyphs =
  Summary_paging.to_page skills_page;
  Summary_paging.settled (fun () -> Frlg_text.Summary_stats.read_stats glyphs)
  |> Option.map miss_stats_of

let read_summary_miss () =
  let glyphs = Text_data.glyphs () in
  let level =
    Summary_paging.settled (fun () -> Frlg_text.Summary_stats.read_level glyphs)
  in
  Option.map
    (fun level ->
      let species = Summary_paging.settled Party_species.read_shown in
      let nature = Frlg_text.Summary_stats.read_nature glyphs in
      let gender = miss_gender_of (Frlg_text.Summary_stats.read_gender ()) in
      let stats = read_page2_stats glyphs in
      { species; observation = { MS.nature; gender; level; stats } })
    level

let ( let* ) = Result.bind

let load_search_inputs ~species ~seeds ~seed_shift ~target_seed ~target_delay_ms
    =
  let* db = R.Base_stats.load () in
  let* base_stats =
    Option.to_result
      ~none:("base stats not found for species " ^ species)
      (R.Base_stats.find db species)
  in
  let* delays, seed_col = Wild_rng_plan.seed_column_of ~seeds ~seed_shift in
  let* target_seed_index =
    Option.to_result
      ~none:(Printf.sprintf "target seed %04X not in %s" target_seed seeds)
      (MS.find_seed_index ~delays ~seeds:seed_col ~seed:target_seed
         ~table_delay_ms:target_delay_ms)
  in
  Ok (base_stats, delays, seed_col, target_seed_index)

type delta = {
  boot_delta_ms : int;
  ingame_delta : int;
  seed_delta_frames : int;
}

let persist_delta ~log ~label ?calibration_path ~boot_delta_ms ~ingame_delta ()
    =
  match
    R.Switch_rng_calibration.record_timing_miss ?path:calibration_path
      ~boot_delta_ms ~ingame_delta ()
  with
  | Ok _ -> ()
  | Error e -> log (Printf.sprintf "%s calibration warning: %s" label e)

let apply_hit ~log ~label ~persist ~prev_seed_delta ?calibration_path
    (h : MS.hit) =
  let boot_delta_ms, ingame_delta =
    MS.damped_calibration_delta ~prev_seed_delta h
  in
  let msg =
    Printf.sprintf
      "%s calibration: boot_offset_ms += %+d ms, ingame_offset += %+d adv."
      label boot_delta_ms ingame_delta
  in
  log msg;
  if persist then
    persist_delta ~log ~label ?calibration_path ~boot_delta_ms ~ingame_delta ();
  { boot_delta_ms; ingame_delta; seed_delta_frames = h.seed_delta_frames }

let apply_hits ~log ~label ~persist ~prev_seed_delta ?calibration_path =
  function
  | [] -> None
  | h :: _ ->
      Some (apply_hit ~log ~label ~persist ~prev_seed_delta ?calibration_path h)

let finish_search ~log ~label ~target_seed ~target_delay_ms ~target_advance
    ~persist ~prev_seed_delta ?calibration_path hits =
  log (MS.format_miss_report ~target_seed ~target_delay_ms ~target_advance hits);
  apply_hits ~log ~label ~persist ~prev_seed_delta ?calibration_path hits

let report_and_calibrate ~log ~label ~species ~seeds ~seed_shift ~target_seed
    ~target_delay_ms ~target_advance ~persist ?prev_seed_delta ?calibration_path
    obs =
  log (Printf.sprintf "%s: observed %s." label (MS.format_observation obs));
  match
    load_search_inputs ~species ~seeds ~seed_shift ~target_seed ~target_delay_ms
  with
  | Error e ->
      log (Printf.sprintf "%s miss search skipped: %s" label e);
      None
  | Ok (base_stats, delays, seed_col, target_seed_index) ->
      MS.search_method1 ~base_stats ~delays ~seeds:seed_col ~target_seed_index
        ~target_advance obs
      |> finish_search ~log ~label ~target_seed ~target_delay_ms ~target_advance
           ~persist ~prev_seed_delta ?calibration_path

let report_and_calibrate_wild ~log ~label ~species ~slots ~super_rod ~seeds
    ~seed_shift ~target_seed ~target_delay_ms ~target_advance ~persist
    ?prev_seed_delta ?calibration_path obs =
  log
    (Printf.sprintf "%s: observed %s (%s)." label species
       (MS.format_observation obs));
  match
    load_search_inputs ~species ~seeds ~seed_shift ~target_seed ~target_delay_ms
  with
  | Error e ->
      log (Printf.sprintf "%s miss search skipped: %s" label e);
      None
  | Ok (base_stats, delays, seed_col, target_seed_index) ->
      MS.search_wild ~slots ~super_rod ~species ~base_stats ~delays
        ~seeds:seed_col ~target_seed_index ~target_advance obs
      |> finish_search ~log ~label ~target_seed ~target_delay_ms ~target_advance
           ~persist ~prev_seed_delta ?calibration_path
