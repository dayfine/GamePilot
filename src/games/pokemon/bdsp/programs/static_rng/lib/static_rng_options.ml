module E = Bdsp_rng.Static_encounter
module T = Bdsp_rng.Static_targets

type shiny_filter = Any | Star | Square | Include_non_shiny

type t = {
  target : T.t;
  shiny : shiny_filter;
  delay_ms : int;
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

let unknown_shiny_filter other =
  Printf.sprintf
    "unknown shiny filter %S (expected any|star|square|include_non_shiny)" other

let parse_shiny_filter s =
  match String.lowercase_ascii (String.trim s) with
  | "any" -> Ok Any
  | "star" -> Ok Star
  | "square" -> Ok Square
  | "include_non_shiny" -> Ok Include_non_shiny
  | other -> Error (unknown_shiny_filter other)

let shiny_filter_to_string = function
  | Any -> "any"
  | Star -> "star"
  | Square -> "square"
  | Include_non_shiny -> "include_non_shiny"

let accept_pokemon filter (p : E.pokemon) =
  match (filter, p.shiny) with
  | Include_non_shiny, _ -> true
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
  let* max_attempts =
    int_opt ~key:"max_attempts" ~default:default_values.max_attempts ~min:1
      ~max:option_bounds.max_attempts_limit opts
  in
  let* seed_timeout_s =
    int_opt ~key:"seed_timeout_s" ~default:default_values.seed_timeout_s
      ~min:option_bounds.timeout_min_s ~max:option_bounds.timeout_max_s opts
  in
  Ok { target; shiny; delay_ms; max_attempts; seed_timeout_s }

let format_summary cfg =
  Printf.sprintf
    "target=%s shiny=%s delay_ms=%d max_attempts=%d seed_timeout_s=%d"
    cfg.target.id
    (shiny_filter_to_string cfg.shiny)
    cfg.delay_ms cfg.max_attempts cfg.seed_timeout_s
