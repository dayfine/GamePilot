module J = Json_field
module R = Frlg_rng

type t = {
  species : string;
  location : string;
  tid : int;
  sid : int;
  seeds : string;
  frame_model : string;
  min_advance : int;
  max_advance : int;
  capture : Capture_plan.t;
}

let max_id = 0xffff
let default_min_advance = 900
let default_max_advance = 4000
let default_advances = (default_min_advance, default_max_advance)
let default_attempts = 1
let max_attempts = 99
let assets = "src/games/frlg/assets/"

let encounter_slots =
  "third_party/Packages/Resources/PokemonFRLG/EncounterSlotsFR.json"

let column = "Mono / Help / A"

let frame_models =
  [ ("mgba", R.Rng_timings.mgba); ("switch", R.Rng_timings.switch) ]

let id ~where name args =
  let n = J.int ~where name args in
  if n < 0 || n > max_id then J.fail "%s%s is %d, not 0..65535" where name n
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

let read ~where args =
  let min_advance, max_advance = advances ~where args in
  {
    species = J.string ~where "species" args;
    location = J.string ~where "location" args;
    tid = id ~where "tid" args;
    sid = id ~where "sid" args;
    seeds = J.string ~where "seeds" args;
    frame_model = frame_model ~where args;
    min_advance;
    max_advance;
    capture = capture ~where args;
  }

let decode args = Action_args.decode ~action:"wild_rng" read args
let ( let* ) = Result.bind

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
  | Some c -> Ok (db.delays, c.seeds)
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
    (List.assoc t.frame_model frame_models)
    ~delays ~seeds slots ~species:t.species ~tid_xor_sid:(t.tid lxor t.sid)
    ~min_advance:t.min_advance ~max_advance:t.max_advance

let target t =
  let* column = seed_column t in
  let* slots = slots t in
  Option.to_result ~none:(no_target t) (search t column slots)
