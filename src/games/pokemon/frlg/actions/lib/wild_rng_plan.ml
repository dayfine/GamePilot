module J = Json_field
module R = Frlg_rng

type t = {
  species : string;
  location : string;
  tid : int;
  sid : int;
  seeds : string;
  seed_shift : int;
  ingame_offset : int;
  frame_model : string;
  min_advance : int;
  max_advance : int;
  capture : Capture_plan.t;
}

type trainer_ids = { tid : int option; sid : int option }

let no_trainer_ids = { tid = None; sid = None }
let max_id = 0xffff
let seed_mask = 0xffff
let default_min_advance = 900
let default_max_advance = 4000
let default_advances = (default_min_advance, default_max_advance)
let default_attempts = 1
let max_attempts = 99
let assets = "src/games/pokemon/frlg/assets/"
let encounter_slots = assets ^ "encounter_slots_firered.json"
let column = "Mono / Help / A"
let config_env = "GAMEPILOT_FRLG_CONFIG"
let config_file = "trainer_ids.json"
let ( let* ) = Result.bind

let env_var = function
  | "tid" -> "GAMEPILOT_FRLG_TID"
  | "sid" -> "GAMEPILOT_FRLG_SID"
  | name -> "GAMEPILOT_FRLG_" ^ String.uppercase_ascii name

let check_id ~label n =
  if n < 0 || n > max_id then
    Error (Printf.sprintf "%s is %d, not 0..%d" label n max_id)
  else Ok n

let env_id name =
  let var = env_var name in
  match Sys.getenv_opt var with
  | None | Some "" -> Ok None
  | Some raw -> (
      match int_of_string_opt (String.trim raw) with
      | Some n -> Result.map Option.some (check_id ~label:var n)
      | None -> Error (Printf.sprintf "%s is %S, not 0..%d" var raw max_id))

let json_id ~path name fields =
  match List.assoc_opt name fields with
  | None | Some `Null -> Ok None
  | Some (`Int n) ->
      Result.map Option.some (check_id ~label:(path ^ ": " ^ name) n)
  | Some _ -> Error (Printf.sprintf "%s: %s is not an integer" path name)

let file_trainer_ids () =
  let dir = Repo_io.Repo_files.data_dir config_env "frlg" in
  let path = Filename.concat dir config_file in
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
  match primary with Some _ -> primary | None -> secondary

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

let id ~where name args =
  let n = J.int ~where name args in
  if n < 0 || n > max_id then J.fail "%s%s is %d, not 0..65535" where name n
  else n

let seed_shift ~where args =
  match J.find "seed_shift" args with
  | None -> 0
  | Some _ -> id ~where "seed_shift" args

let max_ingame_offset = 99

let ingame_offset ~where args =
  match J.find "ingame_offset" args with
  | None -> 0
  | Some _ ->
      let n = J.int ~where "ingame_offset" args in
      if abs n > max_ingame_offset then
        J.fail "%singame_offset is %d, not -%d..%d" where n max_ingame_offset
          max_ingame_offset
      else n

let advances ~where args =
  match J.list_opt ~where "advances" args with
  | None -> default_advances
  | Some [ `Int low; `Int high ] when 0 <= low && low <= high -> (low, high)
  | Some _ -> J.fail "%sadvances is not [min, max]" where

let frame_model ~where args =
  let name = J.string ~where "frame_model" args in
  if List.mem_assoc name frame_models then name
  else J.fail "%sframe_model is %s, not mgba or switch" where name

let attempts ~where args =
  match J.find "attempts" args with
  | None -> default_attempts
  | Some _ ->
      let n = J.int ~where "attempts" args in
      if n < 1 || n > max_attempts then
        J.fail "%sattempts is %d, not 1..%d" where n max_attempts
      else n

(* The capture's own args: species, ball, balls; one encounter per attempt. *)
let capture ~where args =
  let plan = Capture_plan.read ~where args in
  { plan with max_encounters = attempts ~where args; catches = 1 }

let resolved_id ~where ~options ~fallback name args =
  match (Run_options.int options name, J.find name args, fallback) with
  | Some n, _, _ -> n
  | None, Some _, _ -> id ~where name args
  | None, None, Some n -> n
  | None, None, None ->
      J.fail "%smissing %s (pass --options %s=N, set %s, or set it in %s)" where
        name name (env_var name) config_file

let read ~options ~fallback ~where args =
  let min_advance, max_advance = advances ~where args in
  let tid = resolved_id ~where ~options ~fallback:fallback.tid "tid" args in
  let sid = resolved_id ~where ~options ~fallback:fallback.sid "sid" args in
  {
    species = J.string ~where "species" args;
    location = J.string ~where "location" args;
    tid;
    sid;
    seeds = J.string ~where "seeds" args;
    seed_shift = seed_shift ~where args;
    ingame_offset = ingame_offset ~where args;
    frame_model = frame_model ~where args;
    min_advance;
    max_advance;
    capture = Capture_plan.apply_options options (capture ~where args);
  }

let decode ?(options = Run_options.none) ?(fallback = no_trainer_ids) args =
  Action_args.decode ~action:"wild_rng" (read ~options ~fallback) args

let json path =
  match Repo_io.Repo_files.locate path with
  | None -> Error (path ^ " not found from the working directory")
  | Some file -> Repo_io.Json_file.read file

let seed_column t =
  let* j = json (assets ^ t.seeds) in
  let* db = R.Seeds_database.of_json j in
  match
    List.find_opt
      (fun (c : R.Seeds_database.column) -> c.name = column)
      db.columns
  with
  | Some c ->
      Ok
        ( db.delays,
          Array.map (fun s -> (s + t.seed_shift) land seed_mask) c.seeds )
  | None -> Error (t.seeds ^ " has no column " ^ column)

let slots t =
  let* j = json encounter_slots in
  let* db = R.Encounters_database.of_json j in
  Option.to_result
    ~none:("no grass slots for " ^ t.location)
    (R.Encounters_database.slots db ~kind:"grass" ~location:t.location)

let no_target t =
  Printf.sprintf "no shiny %s in %s at advances %d..%d" t.species t.seeds
    t.min_advance t.max_advance

let search t (delays, seeds) slots =
  R.Wild_target.find
    ~calibrations:
      { R.Rng_timings.no_calibrations with ingame_offset = t.ingame_offset }
    (List.assoc t.frame_model frame_models)
    ~delays ~seeds slots ~species:t.species ~tid_xor_sid:(t.tid lxor t.sid)
    ~min_advance:t.min_advance ~max_advance:t.max_advance

let target t =
  let* column = seed_column t in
  let* slots = slots t in
  Option.to_result ~none:(no_target t) (search t column slots)
