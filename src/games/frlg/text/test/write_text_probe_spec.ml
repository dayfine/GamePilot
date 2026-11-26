(* Writes the probe specs the text fixtures are made from, for the daemon's
   offline [probe_images] tool: one spec per screen, every line of the screen
   times every candidate it may show, with each candidate's template as a PNG
   next to the spec (probe_images takes a template path relative to the spec).

     dune exec games/frlg/text/test/write_text_probe_spec.exe -- <dir>

   writes <dir>/<screen>.json and <dir>/<screen>/<n>.png. regen_fixtures.sh
   runs it. *)

open Frlg_text

let required path =
  match Data_files.locate path with
  | Some p -> p
  | None -> failwith ("not found from here: " ^ path)

let glyphs = Glyph_table.load (required Data_files.glyph_table)
let small_glyphs = Glyph_table.load (required Data_files.small_glyph_table)
let items = Item_names.load (required Data_files.item_names_eng)

let tm_moves =
  Tm_moves.names (Tm_moves.load (required Data_files.tm_hm_moves_eng))

let moves =
  List.map snd
    (Move_names.load (required (Data_files.move_names ~language:"eng")))

let rows n line = List.init n line

let cells ~rows ~cells cell =
  List.concat (List.init rows (fun r -> List.init cells (cell r)))

let species =
  List.map snd (Species_names.load (required Data_files.species_names_eng))

let dark = Line_reading.ink

(* The Kanto Pokédex's species: the first 151 in the game's order. *)
let kanto_species = 151

(* Each screen: its font, its lines, their candidates and the ink they are read
   in. *)
let screens =
  [
    ( "bag_items",
      glyphs,
      rows 6 Text_lines.bag_row,
      Item_names.in_pocket items Items @ [ "CANCEL" ],
      dark );
    ( "bag_key_items",
      glyphs,
      rows 6 Text_lines.bag_row,
      Item_names.in_pocket items Key_items @ [ "CANCEL" ],
      dark );
    ( "start_menu",
      glyphs,
      rows 7 Text_lines.start_menu_row,
      [ "POKéDEX"; "POKéMON"; "BAG"; "SAVE"; "OPTION"; "EXIT"; "RETIRE" ],
      dark );
    ("tm_case", glyphs, rows 5 Text_lines.tm_case_row, tm_moves, dark);
    ("summary_moves", glyphs, rows 4 Text_lines.summary_move, moves, dark);
    ( "battle_opening",
      glyphs,
      [ Text_lines.battle_message 0 ],
      List.map (fun name -> "Wild " ^ name ^ " appeared!") species,
      Line_reading.light_ink );
    ( "battle_prompt",
      glyphs,
      [ Text_lines.battle_message 1 ],
      [ "POKéMON?" ],
      Line_reading.light_ink );
    ( "bag_counts",
      small_glyphs,
      cells ~rows:7 ~cells:3 Text_lines.bag_count_digit,
      Number_reading.digits,
      dark );
    ( "summary_level",
      glyphs,
      List.init Summary_level.max_digits Text_lines.summary_level_digit,
      Number_reading.digits,
      Summary_level.ink );
    ( "berry_pouch_numbers",
      small_glyphs,
      cells ~rows:7 ~cells:2 Text_lines.berry_pouch_number_digit,
      Number_reading.digits,
      dark );
    ( "pc_message",
      glyphs,
      [ Text_lines.pc_message ],
      [ "Deposit in which BOX?"; "The BOX is full."; "Please remove the MAIL." ],
      dark );
    ( "pokedex_list",
      glyphs,
      rows Text_lines.pokedex_list_rows Text_lines.pokedex_list_name,
      List.filteri (fun i _ -> i < kanto_species) species @ [ "-----" ],
      dark );
    ( "pokedex_numbers",
      small_glyphs,
      cells ~rows:Text_lines.pokedex_list_rows ~cells:3
        Text_lines.pokedex_list_number_digit,
      Number_reading.digits,
      dark );
    ( "naming_entry",
      glyphs,
      List.init 8 (Text_lines.naming_entry_cell ~max_chars:8),
      Naming_keyboard.charset,
      dark );
    ( "card_numbers",
      glyphs,
      List.init 6 Text_lines.trainer_card_money_digit
      @ List.init 3 Text_lines.trainer_card_dex_digit,
      Number_reading.digits,
      dark );
  ]

let write_file path data =
  Out_channel.with_open_bin path (fun oc -> output_string oc data)

(* The candidates the line can draw (a long name may not fit), each template
   named by the line and the candidate's hash: a screen may draw several
   candidates on lines of one id (the mail field's). *)
let line_probes dir screen glyphs ink line candidates =
  let sub = Filename.concat dir screen in
  if not (Sys.file_exists sub) then Sys.mkdir sub 0o755;
  List.filter_map
    (fun text ->
      match Line_reading.template ~ink glyphs line text with
      | Error _ -> None
      | Ok png ->
          let name =
            Printf.sprintf "%s/%s.%x.png" screen line.Text_lines.id
              (Hashtbl.hash text)
          in
          write_file (Filename.concat dir name) png;
          Some (Line_reading.probe ~ink line text ~template:name))
    candidates

(* The mail editor's field 1: each candidate on its own line. *)
let mail_candidates = [ "ABRA"; Mail_fields.unknown_word; Mail_fields.blank ]

let mail_probes dir screen =
  List.concat_map
    (fun text ->
      line_probes dir screen glyphs dark (Mail_fields.line glyphs text) [ text ])
    mail_candidates

(* The box title: each candidate on its own line, centred as the game
   centres it, matched by its dark outline. *)
let box_title_candidates =
  [ "BOX1"; "BOX2"; "Az!…'.,9"; "”‘' A a." ]
  (* The bag-prep code's names (docs/design/FRLG-ACE-Execution.md), each
     item's Boxes 5-8 among them: a name must read as itself, not as a near
     one. *)
  @ [
      "xFUnDRRn";
      "……o/E!n";
      "EE …l‘";
      "E♀BRm";
      "’BRm";
      " FoHIoor";
      "xn";
      "A";
      "G……o";
      "Q……o";
      "J……o";
      "L……o";
      "K……o";
      "EEEJD!n";
      "EEEND!n";
      "EEEOD!n";
      "EEIB!n";
      "EI/!n";
    ]

let box_title_probes dir screen =
  let sub = Filename.concat dir screen in
  if not (Sys.file_exists sub) then Sys.mkdir sub 0o755;
  List.filter_map
    (fun text ->
      match Box_title.template glyphs text with
      | Error _ -> None
      | Ok (line, png) ->
          let name =
            Printf.sprintf "%s/%s.%x.png" screen line.Text_lines.id
              (Hashtbl.hash text)
          in
          write_file (Filename.concat dir name) png;
          Some (Box_title.probe_of line text ~template:name))
    box_title_candidates

let write_spec dir screen probes =
  let request =
    Wire.json_of_message (Request { id = 1; call = Subscribe probes })
  in
  write_file
    (Filename.concat dir (screen ^ ".json"))
    (Yojson.Safe.to_string (Yojson.Safe.Util.member "params" request))

let write_screen dir (screen, glyphs, lines, candidates, ink) =
  write_spec dir screen
    (List.concat_map
       (fun line -> line_probes dir screen glyphs ink line candidates)
       lines)

let () =
  let dir = Sys.argv.(1) in
  List.iter (write_screen dir) screens;
  let mail = "mail_editor" in
  write_spec dir mail (mail_probes dir mail);
  let title = "box_title" in
  write_spec dir title (box_title_probes dir title)
