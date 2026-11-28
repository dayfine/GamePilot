(* Port of PokemonFRLG_RngStatsDatabase.{h,cpp}: base stats database, Gen 3
   nature table, gender lookup, and level-L stat calculation. *)

module String_map = Map.Make (String)

type stats = { hp : int; atk : int; def : int; spa : int; spd : int; spe : int }
type gender = Male | Female | Genderless
type entry = { base : stats; gender_threshold : int }
type t = entry String_map.t

let ( let* ) = Result.bind
let default_path = "src/games/pokemon/frlg/assets/base_stats.json"
let byte_mask = 0xff
let stat_divisor = 100
let hp_level_bonus = 10
let non_hp_bonus = 5
let nature_stat_count = 5
let nature_boost_num = 11
let nature_drop_num = 9
let nature_denom = 10
let atk_index = 0
let def_index = 1
let spe_index = 2
let spa_index = 3
let spd_index = 4

let nature_names =
  [|
    "Hardy";
    "Lonely";
    "Brave";
    "Adamant";
    "Naughty";
    "Bold";
    "Docile";
    "Relaxed";
    "Impish";
    "Lax";
    "Timid";
    "Hasty";
    "Serious";
    "Jolly";
    "Naive";
    "Modest";
    "Mild";
    "Quiet";
    "Bashful";
    "Rash";
    "Calm";
    "Gentle";
    "Sassy";
    "Careful";
    "Quirky";
  |]

let nature_name n =
  if n >= 0 && n < Array.length nature_names then Some nature_names.(n)
  else None

let nature_of_name raw =
  let key = String.lowercase_ascii (String.trim raw) in
  let n = Array.length nature_names in
  let rec loop i =
    if i >= n then None
    else if String.lowercase_ascii nature_names.(i) = key then Some i
    else loop (i + 1)
  in
  loop 0

let parse_stats ~ctx = function
  | `List [ `Int hp; `Int atk; `Int def; `Int spa; `Int spd; `Int spe ] ->
      Ok { hp; atk; def; spa; spd; spe }
  | _ -> Error (ctx ^ ".baseStats must be a 6-int array")

let parse_gender_threshold ~ctx fields =
  match List.assoc_opt "genderThreshold" fields with
  | Some (`Int gender_threshold) -> Ok gender_threshold
  | Some _ -> Error (ctx ^ ".genderThreshold must be an integer")
  | None -> Error (ctx ^ ": missing genderThreshold")

let parse_fields ~ctx fields =
  let* raw_stats =
    Option.to_result
      ~none:(ctx ^ ": missing baseStats")
      (List.assoc_opt "baseStats" fields)
  in
  let* base = parse_stats ~ctx raw_stats in
  let* gender_threshold = parse_gender_threshold ~ctx fields in
  Ok { base; gender_threshold }

let parse_entry ~ctx = function
  | `Assoc fields -> parse_fields ~ctx fields
  | _ -> Error (ctx ^ ": expected a JSON object")

let add_entry acc (species, value) =
  let* map = acc in
  let key = String.lowercase_ascii (String.trim species) in
  let* entry = parse_entry ~ctx:key value in
  Ok (String_map.add key entry map)

let of_json = function
  | `Assoc entries -> List.fold_left add_entry (Ok String_map.empty) entries
  | _ -> Error "base_stats: expected a JSON object"

let load ?path () =
  let* resolved =
    match path with
    | Some p -> Ok p
    | None ->
        Option.to_result
          ~none:(default_path ^ " not found from the working directory")
          (Repo_io.Repo_files.locate default_path)
  in
  let* json = Repo_io.Json_file.read resolved in
  of_json json |> Result.map_error (fun e -> resolved ^ ": " ^ e)

let find db species =
  String_map.find_opt (String.lowercase_ascii (String.trim species)) db

let gender_of_pid ~pid ~gender_threshold =
  match
    Pokemon_generation.gender_of_value (pid land byte_mask)
      ~threshold:gender_threshold
  with
  | None -> Genderless
  | Some Female -> Female
  | Some Male -> Male

let apply_nature ~nature ~stat_index raw =
  let inc = nature / nature_stat_count in
  let dec = nature mod nature_stat_count in
  if inc = dec then raw
  else if stat_index = inc then raw * nature_boost_num / nature_denom
  else if stat_index = dec then raw * nature_drop_num / nature_denom
  else raw

let non_hp_stat ~nature ~stat_index ~base ~iv ~level =
  let raw = (((2 * base) + iv) * level / stat_divisor) + non_hp_bonus in
  apply_nature ~nature ~stat_index raw

let compute_stats ~base ~nature ~(ivs : Pokemon_generation.ivs) ~level =
  let hp =
    if base.hp = 1 then 1
    else
      (((2 * base.hp) + ivs.hp) * level / stat_divisor) + level + hp_level_bonus
  in
  {
    hp;
    atk =
      non_hp_stat ~nature ~stat_index:atk_index ~base:base.atk ~iv:ivs.attack
        ~level;
    def =
      non_hp_stat ~nature ~stat_index:def_index ~base:base.def ~iv:ivs.defense
        ~level;
    spa =
      non_hp_stat ~nature ~stat_index:spa_index ~base:base.spa ~iv:ivs.spatk
        ~level;
    spd =
      non_hp_stat ~nature ~stat_index:spd_index ~base:base.spd ~iv:ivs.spdef
        ~level;
    spe =
      non_hp_stat ~nature ~stat_index:spe_index ~base:base.spe ~iv:ivs.speed
        ~level;
  }
