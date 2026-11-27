module E = Bdsp_rng.Static_encounter
module T = Bdsp_rng.Static_targets

type shiny_filter = Any | Star | Square | All

type t = {
  target : T.t;
  shiny : shiny_filter;
  delay_ms : int;
  sync_nature : int option;
  max_attempts : int;
  seed_timeout_s : int;
}

type defaults = {
  target_id : string;
  shiny : string;
  delay_ms : int;
  max_attempts : int;
  seed_timeout_s : int;
}

let default_values =
  {
    target_id = "kyogre";
    shiny = "any";
    delay_ms = 200;
    max_attempts = 20;
    seed_timeout_s = 600;
  }

let nature_count = 25

let nature_index_of_string s =
  let needle = String.lowercase_ascii (String.trim s) in
  let rec loop i =
    if i >= nature_count then None
    else if String.lowercase_ascii (E.nature_name i) = needle then Some i
    else loop (i + 1)
  in
  loop 0

let parse_shiny_filter s =
  match String.lowercase_ascii (String.trim s) with
  | "any" -> Ok Any
  | "star" -> Ok Star
  | "square" -> Ok Square
  | "all" -> Ok All
  | other ->
      Error
        (Printf.sprintf "unknown shiny filter %S (expected any|star|square|all)"
           other)

let shiny_filter_to_string = function
  | Any -> "any"
  | Star -> "star"
  | Square -> "square"
  | All -> "all"

let accept_pokemon filter (p : E.pokemon) =
  match (filter, p.shiny) with
  | All, _ -> true
  | Any, (E.Star | E.Square) -> true
  | Star, E.Star -> true
  | Square, E.Square -> true
  | _ -> false

let parse_target opts =
  let id =
    Option.value ~default:default_values.target_id
      (Run_options.find opts "target")
  in
  match T.find id with
  | Some target -> Ok target
  | None -> Error (Printf.sprintf "unknown static target %S" id)

let parse_sync opts =
  match Run_options.find opts "sync" with
  | None -> Ok None
  | Some name -> (
      match nature_index_of_string name with
      | Some idx -> Ok (Some idx)
      | None -> Error (Printf.sprintf "unknown Synchronize nature %S" name))

let int_opt ~key ~default ~min ~max opts =
  let v = Option.value ~default (Run_options.int opts key) in
  if v < min || v > max then
    Error (Printf.sprintf "%s=%d out of range [%d..%d]" key v min max)
  else Ok v

type bounds = {
  delay_min_ms : int;
  delay_max_ms : int;
  max_attempts_limit : int;
  timeout_min_s : int;
  timeout_max_s : int;
}

let option_bounds =
  {
    delay_min_ms = -5000;
    delay_max_ms = 5000;
    max_attempts_limit = 999;
    timeout_min_s = 60;
    timeout_max_s = 3600;
  }

let ( let* ) = Result.bind

let of_run_options opts =
  let* target = parse_target opts in
  let shiny_raw =
    Option.value ~default:default_values.shiny (Run_options.find opts "shiny")
  in
  let* shiny = parse_shiny_filter shiny_raw in
  let* delay_ms =
    int_opt ~key:"delay_ms" ~default:default_values.delay_ms
      ~min:option_bounds.delay_min_ms ~max:option_bounds.delay_max_ms opts
  in
  let* sync_nature = parse_sync opts in
  let* max_attempts =
    int_opt ~key:"max_attempts" ~default:default_values.max_attempts ~min:1
      ~max:option_bounds.max_attempts_limit opts
  in
  let* seed_timeout_s =
    int_opt ~key:"seed_timeout_s" ~default:default_values.seed_timeout_s
      ~min:option_bounds.timeout_min_s ~max:option_bounds.timeout_max_s opts
  in
  Ok { target; shiny; delay_ms; sync_nature; max_attempts; seed_timeout_s }

let format_summary cfg =
  let sync_text =
    match cfg.sync_nature with None -> "none" | Some idx -> E.nature_name idx
  in
  Printf.sprintf
    "target=%s shiny=%s delay_ms=%d sync=%s max_attempts=%d seed_timeout_s=%d"
    cfg.target.id
    (shiny_filter_to_string cfg.shiny)
    cfg.delay_ms sync_text cfg.max_attempts cfg.seed_timeout_s
