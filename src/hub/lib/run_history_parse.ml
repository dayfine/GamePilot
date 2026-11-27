type tsv_row = {
  ended_ms : int;
  checkpoint : string;
  mode : string;
  result : string;
  at : string;
  reason : string;
}

let ( let* ) = Option.bind
let max_run_name_len = 200
let initial_tbl_size = 64
let ms_per_sec = 1000
let tm_year_epoch = 1900
let year_digits = 4
let two_digits = 2
let min_month = 1
let max_month = 12
let min_day = 1
let max_day = 31
let max_hour = 23
let max_min_sec = 59

let known_modes =
  [ "testing"; "verification"; "preflight"; "single"; "run"; "bring-up" ]

let checkpoint_programs =
  lazy
    (List.concat_map
       (fun (p : Program_registry.t) ->
         List.map (fun cp -> (cp, p)) (Ui_api.checkpoints_of p))
       Program_registry.all)

let is_game_prefix s = String.length s > 0 && s.[0] >= 'a' && s.[0] <= 'z'

let all_digits s =
  String.length s > 0 && String.for_all (fun c -> c >= '0' && c <= '9') s

let is_valid_char c =
  (c >= '0' && c <= '9')
  || (c >= 'a' && c <= 'z')
  || (c >= 'A' && c <= 'Z')
  || c = '-' || c = '_' || c = '.'

let valid_run_name name =
  let len = String.length name in
  len > 0 && len <= max_run_name_len
  && name.[0] <> '.'
  && String.for_all is_valid_char name

let infer_game_from_id id =
  match String.index_opt id '.' with
  | Some i when i > 0 ->
      let prefix = String.sub id 0 i in
      if is_game_prefix prefix then prefix else ""
  | _ -> ""

let lookup_program ~program ~checkpoint =
  match Program_registry.find program with
  | Some _ as p -> p
  | None -> (
      match Program_registry.find checkpoint with
      | Some _ as p -> p
      | None -> List.assoc_opt checkpoint (Lazy.force checkpoint_programs))

let game_name_of_id id =
  match
    List.find_opt
      (fun (g : Program_registry.game) -> g.game_id = id)
      Program_registry.games
  with
  | Some g -> g.game_name
  | None -> ""

let parse_int_in lo hi s =
  match int_of_string_opt s with
  | Some n when n >= lo && n <= hi -> Some n
  | _ -> None

let split_triple sep s =
  match String.split_on_char sep s with
  | [ a; b; c ] -> Some (a, b, c)
  | _ -> None

let make_tm y m d h mn s =
  {
    Unix.tm_sec = s;
    tm_min = mn;
    tm_hour = h;
    tm_mday = d;
    tm_mon = m - 1;
    tm_year = y - tm_year_epoch;
    tm_wday = 0;
    tm_yday = 0;
    tm_isdst = false;
  }

let local_time_ms_opt text =
  let* date, time =
    match String.split_on_char 'T' (String.trim text) with
    | [ d; t ] -> Some (d, t)
    | _ -> None
  in
  let* ys, ms, ds = split_triple '-' date in
  let* hs, mins, ss = split_triple ':' time in
  let* y = int_of_string_opt ys in
  let* () = if y >= tm_year_epoch then Some () else None in
  let* m = parse_int_in min_month max_month ms in
  let* d = parse_int_in min_day max_day ds in
  let* h = parse_int_in 0 max_hour hs in
  let* mn = parse_int_in 0 max_min_sec mins in
  let* s = parse_int_in 0 max_min_sec ss in
  let sec, _ = Unix.mktime (make_tm y m d h mn s) in
  Some (int_of_float (sec *. float_of_int ms_per_sec))

let local_time_ms text = Option.value (local_time_ms_opt text) ~default:0

let strip_mode_suffix body =
  List.find_map
    (fun mode ->
      let suffix = "-" ^ mode in
      let slen = String.length suffix and blen = String.length body in
      if blen > slen && String.ends_with ~suffix body then
        Some (String.sub body 0 (blen - slen), mode)
      else None)
    known_modes

let is_date_parts y m d =
  String.length y = year_digits
  && String.length m = two_digits
  && String.length d = two_digits
  && all_digits y && all_digits m && all_digits d

let parse_run_name name =
  match String.split_on_char '-' name with
  | y :: m :: d :: rest when is_date_parts y m d -> (
      match List.rev rest with
      | n :: mid when all_digits n && mid <> [] ->
          strip_mode_suffix (String.concat "-" (List.rev mid))
      | _ -> None)
  | _ -> None

let field_at cols i =
  Option.fold ~none:"" ~some:String.trim (List.nth_opt cols i)

let make_tsv_row time cp mode res rest =
  {
    ended_ms = local_time_ms time;
    checkpoint = String.trim cp;
    mode = String.trim mode;
    result = String.trim res;
    at = field_at rest 0;
    reason = field_at rest 1;
  }

let tsv_row_of_cols = function
  | time :: run :: cp :: mode :: res :: rest when String.trim run <> "" ->
      Some (String.trim run, make_tsv_row time cp mode res rest)
  | _ -> None

let parse_tsv_line line =
  let trimmed = String.trim line in
  if trimmed = "" || String.starts_with ~prefix:"time\t" trimmed then None
  else tsv_row_of_cols (String.split_on_char '\t' line)

let tsv_table text =
  let tbl = Hashtbl.create initial_tbl_size in
  let add line =
    Option.iter
      (fun (run, row) -> Hashtbl.replace tbl run row)
      (parse_tsv_line line)
  in
  List.iter add (String.split_on_char '\n' text);
  tbl
