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

let frame_model_for_backend = function
  | "switch" -> "switch"
  | _ -> default_frame_model

let column = "Mono / Help / A"
let config_env = "GAMEPILOT_FRLG_CONFIG"
let config_file = "trainer_ids.json"
let ( let* ) = Result.bind

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
  if n < 0 || n > max_id then
    Error (Printf.sprintf "%s is %d, not 0..%d" label n max_id)
  else Ok n

let env_id name =
  let var = env_var name in
  match Sys.getenv_opt var with
  | None | Some "" -> Ok None
  | Some raw ->
      Option.fold
        (int_of_string_opt (String.trim raw))
        ~none:(Error (Printf.sprintf "%s is %S, not 0..%d" var raw max_id))
        ~some:(fun n -> Result.map Option.some (check_id ~label:var n))

let json_id ~path name fields =
  match List.assoc_opt name fields with
  | None | Some `Null -> Ok None
  | Some (`Int n) ->
      Result.map Option.some (check_id ~label:(path ^ ": " ^ name) n)
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

let pick primary secondary =
  if Option.is_some primary then primary else secondary

let load_trainer_ids () =
  let* env_tid = env_id "tid" in
  let* env_sid = env_id "sid" in
  match (env_tid, env_sid) with
  | Some _, Some _ -> Ok { tid = env_tid; sid = env_sid }
  | _ ->
      let* file = file_trainer_ids () in
      Ok { tid = pick env_tid file.tid; sid = pick env_sid file.sid }

let frame_models =
  [ ("mgba", R.Rng_timings.mgba); ("switch", R.Rng_timings.switch) ]

let find_frame_model name = List.assoc_opt name frame_models

let opt_int ~where ~default ~low ~high name args =
  match J.find name args with
  | None -> default
  | Some _ ->
      let n = J.int ~where name args in
      if n >= low && n <= high then n
      else J.fail "%s%s is %d, not %d..%d" where name n low high

let id ~where name args =
  opt_int ~where ~default:0 ~low:0 ~high:max_id name args

let advances ~where args =
  match J.list_opt ~where "advances" args with
  | None -> (default_min_advance, default_max_advance)
  | Some [ `Int low; `Int high ] when 0 <= low && low <= high -> (low, high)
  | Some _ -> J.fail "%sadvances is not [min, max]" where

let frame_model ?(default = default_frame_model) ~where args =
  let name = Option.value ~default (J.string_opt ~where "frame_model" args) in
  if List.mem_assoc name frame_models then name
  else J.fail "%sframe_model is %s, not mgba or switch" where name

let encounter_method ~where args =
  match J.string_opt ~where "method" args with
  | None | Some "grass" -> Grass
  | Some "surf" -> Surf
  | Some "super_rod" -> Super_rod
  | Some other ->
      J.fail "%smethod is %s, not grass, surf, or super_rod" where other

let catch_mode ~where (c : Capture_plan.t) args =
  let module B = Battle_catch_steps in
  let wrap policy = Catch_policy { policy; config = default_catch_config } in
  let ball_name = c.ball and max_balls = c.max_balls in
  match J.string_opt ~where "catch_mode" args with
  | None | Some "throw_only" -> Throw_only
  | Some "phase1" ->
      wrap (B.phase1_policy ~ball_name ~max_balls B.default_phase1_slots)
  | Some "phase2" ->
      wrap (B.phase2_policy ~ball_name ~max_balls B.default_phase2_slots)
  | Some other ->
      J.fail "%scatch_mode is %s, not throw_only, phase1, or phase2" where other

let visual_shiny_check ~where args =
  match J.find "visual_shiny_check" args with
  | None -> false
  | Some (`Bool b) -> b
  | Some _ -> J.fail "%svisual_shiny_check is not a boolean" where

let capture ~where args =
  let plan = Capture_plan.read ~where args in
  let max_encounters =
    opt_int ~where ~default:default_attempts ~low:1 ~high:max_attempts
      "attempts" args
  in
  { plan with max_encounters; catches = 1 }

let resolved_id ~where ~options ~fallback name args =
  match (Run_options.int options name, J.find name args, fallback) with
  | Some n, _, _ -> n
  | None, Some _, _ -> id ~where name args
  | None, None, Some n -> n
  | None, None, None ->
      J.fail "%smissing %s (pass --options %s=N, set %s, or set it in %s)" where
        name name (env_var name) config_file

let read ~options ~fallback ~default_frame_model ~where args =
  let min_advance, max_advance = advances ~where args in
  let tid = resolved_id ~where ~options ~fallback:fallback.tid "tid" args in
  let sid = resolved_id ~where ~options ~fallback:fallback.sid "sid" args in
  let cap = Capture_plan.apply_options options (capture ~where args) in
  {
    encounter_method = encounter_method ~where args;
    species = J.string ~where "species" args;
    location = J.string ~where "location" args;
    tid;
    sid;
    seeds =
      Option.value ~default:default_seeds (J.string_opt ~where "seeds" args);
    boot_offset_ms = 0;
    seed_shift = opt_int ~where ~default:0 ~low:0 ~high:max_id "seed_shift" args;
    ingame_offset =
      opt_int ~where ~default:0 ~low:(-max_ingame_offset)
        ~high:max_ingame_offset "ingame_offset" args;
    frame_model = frame_model ~default:default_frame_model ~where args;
    min_advance;
    max_advance;
    capture = cap;
    catch_mode = catch_mode ~where cap args;
    visual_shiny_check = visual_shiny_check ~where args;
  }

let apply_calibration (entry : R.Switch_rng_calibration.entry) t =
  {
    t with
    boot_offset_ms = t.boot_offset_ms + entry.boot_offset_ms;
    seed_shift = (t.seed_shift + entry.seed_shift) land seed_mask;
    ingame_offset = t.ingame_offset + entry.ingame_offset;
  }

let decode ?(options = Run_options.none) ?(fallback = no_trainer_ids)
    ?(default_frame_model = default_frame_model) args =
  let f = read ~options ~fallback ~default_frame_model in
  Action_args.decode ~action:"wild_rng" f args

let json path =
  match Repo_io.Repo_files.locate path with
  | None -> Error (path ^ " not found from the working directory")
  | Some file -> Repo_io.Json_file.read file

let seed_column_of ~seeds ~seed_shift =
  let* j = json (assets ^ seeds) in
  let* db = R.Seeds_database.of_json j in
  let has_col (c : R.Seeds_database.column) = c.name = column in
  match List.find_opt has_col db.columns with
  | Some c ->
      let shift s = (s + seed_shift) land seed_mask in
      Ok (db.delays, Array.map shift c.seeds)
  | None -> Error (seeds ^ " has no column " ^ column)

let slots t =
  let kind = encounter_table_kind t.encounter_method in
  let* j = json encounter_slots in
  let* db = R.Encounters_database.of_json j in
  Option.to_result
    ~none:("no " ^ kind ^ " slots for " ^ t.location)
    (R.Encounters_database.slots db ~kind ~location:t.location)

let no_target t =
  Printf.sprintf "no shiny %s in %s at advances %d..%d" t.species t.seeds
    t.min_advance t.max_advance

let calibrations_of_offsets ~boot_offset_ms ~ingame_offset
    (model : R.Rng_timings.frame_model) =
  let seed_offset =
    if boot_offset_ms = 0 then 0
    else
      int_of_float
        (Float.round (float_of_int boot_offset_ms /. model.frame_duration_ms))
  in
  { R.Rng_timings.no_calibrations with seed_offset; ingame_offset }

let search t (delays, seeds) slots =
  let model = List.assoc t.frame_model frame_models in
  let calibrations =
    calibrations_of_offsets ~boot_offset_ms:t.boot_offset_ms
      ~ingame_offset:t.ingame_offset model
  in
  let super_rod = t.encounter_method = Super_rod in
  R.Wild_target.find ~calibrations ~super_rod model ~delays ~seeds slots
    ~species:t.species ~tid_xor_sid:(t.tid lxor t.sid)
    ~min_advance:t.min_advance ~max_advance:t.max_advance

let target t =
  let* column = seed_column_of ~seeds:t.seeds ~seed_shift:t.seed_shift in
  let* slots = slots t in
  Option.to_result ~none:(no_target t) (search t column slots)
