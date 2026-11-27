module J = Json_field
module R = Frlg_rng
module CS = Pokemon_catch.Catch_state

type encounter_method = Grass | Surf | Super_rod

type catch_mode =
  | Throw_only
  | Catch_policy of { policy : CS.policy; config : Battle_catch_steps.config }

type t = {
  encounter_method : encounter_method;
  species : string;
  location : string;
  tid : int;
  sid : int;
  seeds : string;
  boot_offset_ms : int;
  seed_shift : int;
  ingame_offset : int;
  frame_model : string;
  min_advance : int;
  max_advance : int;
  capture : Capture_plan.t;
  catch_mode : catch_mode;
  visual_shiny_check : bool;
}

type trainer_ids = { tid : int option; sid : int option }

let max_id = 0xffff
let seed_mask = 0xffff
let default_min_advance = 900
let default_max_advance = 4000
let default_attempts = 1
let max_attempts = 99
let max_ingame_offset = 99
let throw_only_max_turns = 80
let no_trainer_ids = { tid = None; sid = None }
let assets = "src/games/pokemon/frlg/assets/"
let encounter_slots = assets ^ "encounter_slots_firered.json"
let default_seeds = "rng_seeds_mgba_sevii_save.json"
let default_frame_model = "mgba"
let column = "Mono / Help / A"
let config_env = "GAMEPILOT_FRLG_CONFIG"
let config_file = "trainer_ids.json"
let ( let* ) = Result.bind

let default_seeds_for_model m =
  if m = "switch" then "rng_seeds_switch_fr_eng.json" else default_seeds

let frame_model_for_backend b =
  if b = "switch" then "switch" else default_frame_model

let encounter_method_to_string = function
  | Grass -> "grass"
  | Surf -> "surf"
  | Super_rod -> "super_rod"

let encounter_table_kind = function
  | Grass -> "grass"
  | Surf -> "surfing"
  | Super_rod -> "superrod"

let default_catch_config : Battle_catch_steps.config =
  {
    initial_active_slot = 1;
    bag = { ball_row = 0; heal_row = 0 };
    event_timeout_ms = Battle_catch_steps.default_event_timeout_ms;
  }

let throw_only_policy (capture : Capture_plan.t) : CS.policy =
  {
    status_setter = None;
    false_swiper = None;
    wall = None;
    ball_name = capture.ball;
    max_balls = capture.max_balls;
    foe_hp_target = 1.0;
    foe_hp_rechip = 1.0;
    reapply_status = false;
    max_turns = throw_only_max_turns;
    send_in_order = [ 1; 2; 3; 4; 5 ];
  }

let env_var name = "GAMEPILOT_FRLG_" ^ String.uppercase_ascii name

let check_id ~label n =
  if n >= 0 && n <= max_id then Ok (Some n)
  else Error (Printf.sprintf "%s is %d, not 0..%d" label n max_id)

let env_id name =
  let var = env_var name in
  match Sys.getenv_opt var with
  | None | Some "" -> Ok None
  | Some raw -> (
      match int_of_string_opt (String.trim raw) with
      | None -> Error (Printf.sprintf "%s is %S, not 0..%d" var raw max_id)
      | Some n -> check_id ~label:var n)

let json_id ~path name fields =
  match List.assoc_opt name fields with
  | None | Some `Null -> Ok None
  | Some (`Int n) -> check_id ~label:(path ^ ": " ^ name) n
  | Some _ -> Error (Printf.sprintf "%s: %s is not an integer" path name)

let file_trainer_ids () =
  let path =
    Filename.concat (Repo_io.Repo_files.data_dir config_env "frlg") config_file
  in
  if not (Sys.file_exists path) then Ok no_trainer_ids
  else
    let* json = Repo_io.Json_file.read path in
    match json with
    | `Assoc fields ->
        let* tid = json_id ~path "tid" fields in
        let* sid = json_id ~path "sid" fields in
        Ok { tid; sid }
    | _ -> Error (path ^ ": expected a JSON object")

let pick a b = if Option.is_some a then a else b

let load_trainer_ids () =
  let* tid = env_id "tid" in
  let* sid = env_id "sid" in
  if Option.is_some tid && Option.is_some sid then Ok { tid; sid }
  else
    let* f = file_trainer_ids () in
    Ok { tid = pick tid f.tid; sid = pick sid f.sid }

let find_frame_model = function
  | "mgba" -> Some R.Rng_timings.mgba
  | "switch" -> Some R.Rng_timings.switch
  | _ -> None

let opt_int ~where ~default ~low ~high name args =
  match J.find name args with
  | None -> default
  | Some _ ->
      let n = J.int ~where name args in
      if n >= low && n <= high then n
      else J.fail "%s%s is %d, not %d..%d" where name n low high

let visual_shiny_check ~where args =
  match J.find "visual_shiny_check" args with
  | None -> false
  | Some (`Bool b) -> b
  | Some _ -> J.fail "%svisual_shiny_check is not a boolean" where

let advances ~where args =
  match J.list_opt ~where "advances" args with
  | None -> (default_min_advance, default_max_advance)
  | Some [ `Int low; `Int high ] when 0 <= low && low <= high -> (low, high)
  | Some _ -> J.fail "%sadvances is not [min, max]" where

let frame_model ?(default = default_frame_model) ~where args =
  let name = Option.value ~default (J.string_opt ~where "frame_model" args) in
  if Option.is_some (find_frame_model name) then name
  else J.fail "%sframe_model is %s, not mgba or switch" where name

let encounter_method ~where args =
  match J.string_opt ~where "method" args with
  | None | Some "grass" -> Grass
  | Some "surf" -> Surf
  | Some "super_rod" -> Super_rod
  | Some other ->
      J.fail "%smethod is %s, not grass, surf, or super_rod" where other

let catch_mode ~where ~options (c : Capture_plan.t) args =
  let module B = Battle_catch_steps in
  let wrap p = Catch_policy { policy = p; config = default_catch_config } in
  let ball_name = c.ball and max_balls = c.max_balls in
  match
    pick
      (Run_options.find options "catch_mode")
      (J.string_opt ~where "catch_mode" args)
  with
  | None | Some "throw_only" -> Throw_only
  | Some "phase1" ->
      wrap (B.phase1_policy ~ball_name ~max_balls B.default_phase1_slots)
  | Some "phase2" ->
      wrap (B.phase2_policy ~ball_name ~max_balls B.default_phase2_slots)
  | Some other ->
      J.fail "%scatch_mode is %s, not throw_only, phase1, or phase2" where other

let resolved_attempts ~where ~options args =
  match Run_options.int options "attempts" with
  | Some n when n >= 1 && n <= max_attempts -> n
  | _ ->
      opt_int ~where ~default:default_attempts ~low:1 ~high:max_attempts
        "attempts" args

let resolved_id ~where ~options ~fallback name args =
  match (Run_options.int options name, J.find name args, fallback) with
  | Some n, _, _ -> n
  | None, Some _, _ -> opt_int ~where ~default:0 ~low:0 ~high:max_id name args
  | None, None, Some n -> n
  | None, None, None ->
      J.fail "%smissing %s (pass --options %s=N, set %s, or set it in %s)" where
        name name (env_var name) config_file

let read ~options ~fallback ~default_frame_model ~where args =
  let min_advance, max_advance = advances ~where args in
  let tid = resolved_id ~where ~options ~fallback:fallback.tid "tid" args in
  let sid = resolved_id ~where ~options ~fallback:fallback.sid "sid" args in
  let p = Capture_plan.read ~where args in
  let max_encounters = resolved_attempts ~where ~options args in
  let cap =
    Capture_plan.apply_options options { p with max_encounters; catches = 1 }
  in
  let frame_model = frame_model ~default:default_frame_model ~where args in
  let opt = opt_int ~where ~default:0 in
  let default = default_seeds_for_model frame_model in
  {
    encounter_method = encounter_method ~where args;
    species = J.string ~where "species" args;
    location = J.string ~where "location" args;
    tid;
    sid;
    seeds = Option.value ~default (J.string_opt ~where "seeds" args);
    boot_offset_ms = 0;
    seed_shift = opt ~low:0 ~high:max_id "seed_shift" args;
    ingame_offset =
      opt ~low:(-max_ingame_offset) ~high:max_ingame_offset "ingame_offset" args;
    frame_model;
    min_advance;
    max_advance;
    capture = cap;
    catch_mode = catch_mode ~where ~options cap args;
    visual_shiny_check = visual_shiny_check ~where args;
  }

let apply_timing_delta ~boot_delta_ms ~ingame_delta t =
  {
    t with
    boot_offset_ms = t.boot_offset_ms + boot_delta_ms;
    ingame_offset = t.ingame_offset + ingame_delta;
  }

let apply_calibration (e : R.Switch_rng_calibration.entry) t =
  let seed_shift = (t.seed_shift + e.seed_shift) land seed_mask in
  apply_timing_delta ~boot_delta_ms:e.boot_offset_ms
    ~ingame_delta:e.ingame_offset { t with seed_shift }

let decode ?(options = Run_options.none) ?(fallback = no_trainer_ids)
    ?(default_frame_model = default_frame_model) args =
  Action_args.decode ~action:"wild_rng"
    (read ~options ~fallback ~default_frame_model)
    args

let json path =
  match Repo_io.Repo_files.locate path with
  | Some p -> Repo_io.Json_file.read p
  | None -> Error (path ^ " not found from the working directory")

let seed_column_of ~seeds ~seed_shift =
  let* j = json (assets ^ seeds) in
  let* db = R.Seeds_database.of_json j in
  let has (c : R.Seeds_database.column) = c.name = column in
  let shift s = (s + seed_shift) land seed_mask in
  match List.find_opt has db.columns with
  | Some c -> Ok (db.delays, Array.map shift c.seeds)
  | None -> Error (seeds ^ " has no column " ^ column)

let slots t =
  let kind = encounter_table_kind t.encounter_method in
  let* j = json encounter_slots in
  let* db = R.Encounters_database.of_json j in
  R.Encounters_database.slots db ~kind ~location:t.location
  |> Option.to_result ~none:("no " ^ kind ^ " slots for " ^ t.location)

let calibrated_model ~boot_offset_ms ~ingame_offset
    (m : R.Rng_timings.frame_model) =
  let fixed_seed_offset_ms = m.fixed_seed_offset_ms + boot_offset_ms in
  ( { m with fixed_seed_offset_ms },
    { R.Rng_timings.no_calibrations with ingame_offset } )

let target t =
  let* delays, seeds = seed_column_of ~seeds:t.seeds ~seed_shift:t.seed_shift in
  let* slots = slots t in
  let* raw =
    find_frame_model t.frame_model
    |> Option.to_result ~none:("unknown frame_model " ^ t.frame_model)
  in
  let model, calibrations =
    calibrated_model ~boot_offset_ms:t.boot_offset_ms
      ~ingame_offset:t.ingame_offset raw
  in
  let none =
    Printf.sprintf "no shiny %s in %s at advances %d..%d" t.species t.seeds
      t.min_advance t.max_advance
  in
  R.Wild_target.find ~calibrations
    ~super_rod:(t.encounter_method = Super_rod)
    model ~delays ~seeds slots ~species:t.species
    ~tid_xor_sid:(t.tid lxor t.sid) ~min_advance:t.min_advance
    ~max_advance:t.max_advance
  |> Option.to_result ~none
