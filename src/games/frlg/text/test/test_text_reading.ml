(* The text reader on real screenshots. The fixtures are the daemon's
   [probe_images] output for the specs write_text_probe_spec.exe writes (one
   per screen), over the images images.map names, each line trimmed to its best
   candidates; CommandLineTests images stay in that repo. Image paths start
   with their source: switch_clt (the fork's CommandLineTests/PokemonFRLG), switch_lab
   (Switch captures under readers/test/images/switch) and mgba (mGBA frames
   under readers/test/images/mgba). regen_fixtures.sh makes them again. *)

open Frlg_text

let screens =
  [
    "bag_items";
    "bag_key_items";
    "tm_case";
    "summary_moves";
    "battle_opening";
    "battle_prompt";
    "bag_counts";
    "berry_pouch_numbers";
    "summary_level";
    "mail_editor";
    "start_menu";
    "card_numbers";
    "pokedex_list";
    "pokedex_numbers";
    "pc_message";
    "naming_entry";
  ]

let glyphs =
  match Data_files.locate Data_files.glyph_table with
  | Some path -> Glyph_table.load path
  | None -> failwith "glyph table not found"

(* The mail editor's field: each candidate on a line of its own width. *)
let mail_field = "mail_field.1"

(* A line and the score its reader allows: small-font digits and the summary's
   level have their own. *)
let line_of_id id =
  let normal line = (line, Line_reading.max_score)
  and small line = (line, Number_reading.small_max_score) in
  match String.split_on_char '.' id with
  | [ "bag"; i ] -> normal (Text_lines.bag_row (int_of_string i))
  | [ "start_menu_name"; i ] ->
      normal (Text_lines.start_menu_row (int_of_string i))
  | [ "tm_case"; i ] -> normal (Text_lines.tm_case_row (int_of_string i))
  | [ "summary_move"; i ] -> normal (Text_lines.summary_move (int_of_string i))
  | [ "battle_message"; i ] ->
      normal (Text_lines.battle_message (int_of_string i))
  | [ "bag_count"; row; k ] ->
      small (Text_lines.bag_count_digit (int_of_string row) (int_of_string k))
  | [ "pouch_number"; row; k ] ->
      small
        (Text_lines.berry_pouch_number_digit (int_of_string row)
           (int_of_string k))
  | [ "card_money"; k ] ->
      normal (Text_lines.trainer_card_money_digit (int_of_string k))
  | [ "card_dex"; k ] ->
      normal (Text_lines.trainer_card_dex_digit (int_of_string k))
  | [ "pc_message" ] -> normal Text_lines.pc_message
  | [ "naming_entry"; i ] ->
      normal (Text_lines.naming_entry_cell ~max_chars:8 (int_of_string i))
  | [ "pokedex_name"; row ] ->
      normal (Text_lines.pokedex_list_name (int_of_string row))
  | [ "pokedex_number"; row; k ] ->
      small
        (Text_lines.pokedex_list_number_digit (int_of_string row)
           (int_of_string k))
  | [ "summary_level"; k ] ->
      (Text_lines.summary_level_digit (int_of_string k), Summary_level.max_score)
  | _ -> failwith ("line id " ^ id)

type expectation = {
  image : string;
  line : string;
  shows : string;
  reads : string;  (** what the reader says: [shows] unless a known miss *)
}

let expectation_of_line s =
  match String.split_on_char '|' s with
  | [ image; line; shows ] -> { image; line; shows; reads = shows }
  | [ image; line; shows; reads; _why ] -> { image; line; shows; reads }
  | _ -> failwith ("expected.txt line " ^ s)

let expectations =
  In_channel.with_open_bin "fixtures/expected.txt" In_channel.input_all
  |> String.split_on_char '\n'
  |> List.filter (fun s -> s <> "" && s.[0] <> '#')
  |> List.map expectation_of_line

let frames =
  List.concat_map
    (fun screen ->
      Wire.read_image_probes ("fixtures/" ^ screen ^ ".probes.jsonl"))
    screens

(* The candidates are the line's probes in the frame: the spec drew them. An
   image probed for several screens has their probes together. *)
let reading (e : expectation) =
  let probes =
    List.concat_map
      (fun (image, probes) -> if image = e.image then probes else [])
      frames
  in
  let prefix = e.line ^ "/" in
  let candidates =
    List.filter_map
      (fun (id, _) ->
        if String.starts_with ~prefix id then
          Some
            (String.sub id (String.length prefix)
               (String.length id - String.length prefix))
        else None)
      probes
  in
  let m : Effects.measurements = { seq = 0; t_ms = 0.; probes } in
  let picked =
    if e.line = mail_field then Mail_fields.pick glyphs candidates m
    else if String.starts_with ~prefix:"naming_entry." e.line then
      let line, max_score = line_of_id e.line in
      Line_reading.pick_preferring ~max_score line
        (List.filter (fun c -> c <> " ") candidates)
        ~fallback:[ " " ] m
    else
      let line, max_score = line_of_id e.line in
      Line_reading.pick ~max_score line candidates m
  in
  match picked with Read { text; _ } -> text | No_match _ -> "-"

let source image = List.hd (String.split_on_char '/' image)

let print_accuracy () =
  let sources =
    List.sort_uniq compare (List.map (fun e -> source e.image) expectations)
  in
  List.iter
    (fun s ->
      let mine = List.filter (fun e -> source e.image = s) expectations in
      let right = List.filter (fun e -> reading e = e.shows) mine in
      Printf.printf "%s: %d/%d lines read right\n" s (List.length right)
        (List.length mine))
    sources

let () =
  print_accuracy ();
  Table_test.run "text_reading"
    (List.map
       (fun e ->
         {
           Table_test.name = e.image ^ " " ^ e.line;
           input = (fun () -> reading e);
           expectation = e.reads;
         })
       expectations)
