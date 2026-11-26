(* Port of PokemonFRLG/Programs/RngManipulation/PokemonFRLG_SeedsDatabase.cpp,
   without the JSON file reading. *)

type sound = Mono | Stereo
type seed_button = A | Start | L
type extra_button = No_extra | Extra_l

let blackout_seed_offset = 0x0024
let max_seed = 0xffff

type column = {
  name : string;
  sound : sound;
  button_mode : string;
  seed_button : seed_button;
  seeds : int array;
}

type t = { delays : int array; columns : column list }

type seed_match = {
  seed_values : int list;
  seed_position : int;
  seed_delay : int;
  seed_button : seed_button;
  extra_button : extra_button;
  sound : sound;
  button_mode : string;
  column_name : string;
}

let ( let* ) = Result.bind

let is_hex_digit = function
  | '0' .. '9' | 'a' .. 'f' | 'A' .. 'F' -> true
  | _ -> false

(* parse_hex_seed: std::stoul in base 16 over the whole text, at most 0xFFFF. *)
let parse_hex_seed text =
  match int_of_string_opt ("0x" ^ text) with
  | Some v when text <> "" && String.for_all is_hex_digit text && v <= max_seed
    ->
      Ok v
  | _ -> Error ("Invalid seed value: " ^ text)

let split_on_separator name =
  let sep = " / " in
  let n = String.length sep in
  let rec go start acc =
    match Substring.find ~from:start name sep with
    | None ->
        List.rev (String.sub name start (String.length name - start) :: acc)
    | Some i -> go (i + n) (String.sub name start (i - start) :: acc)
  in
  go 0 []

let parse_column_name name =
  let* sound, mode, button =
    match split_on_separator name with
    | [ s; m; b ] -> Ok (s, m, b)
    | _ -> Error ("Malformed seed column name: " ^ name)
  in
  let* sound =
    match sound with
    | "Mono" -> Ok Mono
    | "Stereo" -> Ok Stereo
    | _ -> Error ("Unknown sound setting in column: " ^ name)
  in
  match button with
  | "A" -> Ok (sound, mode, A)
  | "START" | "Start" -> Ok (sound, mode, Start)
  | "L" -> Ok (sound, mode, L)
  | _ -> Error ("Unknown seed button in column: " ^ name)

let column (name, texts) =
  let* sound, button_mode, seed_button = parse_column_name name in
  let* seeds =
    List.fold_right
      (fun text acc ->
        let* rest = acc in
        let* seed = parse_hex_seed text in
        Ok (seed :: rest))
      texts (Ok [])
  in
  Ok { name; sound; button_mode; seed_button; seeds = Array.of_list seeds }

let of_columns ~delays named =
  let* columns =
    List.fold_right
      (fun c acc ->
        let* rest = acc in
        let* c = column c in
        Ok (c :: rest))
      named (Ok [])
  in
  Ok { delays; columns }

(* The seeds [radius] rows either side of row [i], without the L offset. *)
let window column ~extra ~radius i =
  let first = max 0 (i - radius) in
  let last = min (Array.length column.seeds - 1) (i + radius) in
  let offset = if extra = Extra_l then blackout_seed_offset else 0 in
  List.init
    (last - first + 1)
    (fun k -> (column.seeds.(first + k) - offset) land max_seed)
  |> fun values -> (values, i - first)

let found t column ~extra ~radius i =
  let seed_values, seed_position = window column ~extra ~radius i in
  {
    seed_values;
    seed_position;
    seed_delay = t.delays.(i);
    seed_button = column.seed_button;
    extra_button = extra;
    sound = column.sound;
    button_mode = column.button_mode;
    column_name = column.name;
  }

(* The first row of [column] holding [value]; it replaces [best] only if its
   delay is earlier. *)
let try_variant t ~radius (column : column) best (extra, value) =
  let rows = min (Array.length column.seeds) (Array.length t.delays) in
  let rec scan i =
    if i >= rows then best
    else if column.seeds.(i) <> value then scan (i + 1)
    else
      match best with
      | Some b when t.delays.(i) >= b.seed_delay -> best
      | _ -> Some (found t column ~extra ~radius i)
  in
  scan 0

let find_seed t ~target sound ~radius =
  let variants =
    [
      (No_extra, target);
      (Extra_l, (target + blackout_seed_offset) land max_seed);
    ]
  in
  List.fold_left
    (fun best (column : column) ->
      if column.sound <> sound || column.button_mode <> "Help" then best
      else List.fold_left (try_variant t ~radius column) best variants)
    None t.columns

let rec collect f = function
  | [] -> Ok []
  | x :: rest ->
      let* v = f x in
      let* vs = collect f rest in
      Ok (v :: vs)

let json_string key = function
  | `String s -> Ok s
  | _ -> Error ("Seed column " ^ key ^ " holds a non-string")

let json_int = function
  | `Int d -> Ok d
  | _ -> Error "Delay holds a non-integer"

let json_strings key = function
  | `List items -> collect (json_string key) items
  | _ -> Error ("Seed column " ^ key ^ " is not an array")

let json_delays = function
  | `List items -> Result.map Array.of_list (collect json_int items)
  | _ -> Error "Delay is not an array"

let json_column (key, v) =
  let* seeds = json_strings key v in
  Ok (key, seeds)

let by_name (a, _) (b, _) = String.compare a b

let of_fields fields =
  let* delays =
    Option.fold ~none:(Error "No Delay array in the seed file")
      ~some:json_delays
      (List.assoc_opt "Delay" fields)
  in
  let named = List.filter (fun (k, _) -> k <> "Delay") fields in
  let* columns = collect json_column (List.sort by_name named) in
  of_columns ~delays columns

let of_json = function
  | `Assoc fields -> of_fields fields
  | _ -> Error "The seed file is not an object"
