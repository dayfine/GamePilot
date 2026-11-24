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
    (Move_names.load ~language:"eng" (required Data_files.move_names))

let rows n line = List.init n line

let cells ~rows ~cells cell =
  List.concat (List.init rows (fun r -> List.init cells (cell r)))

let species =
  List.map snd (Species_names.load (required Data_files.species_names_eng))

let dark = Line_reading.ink

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
  write_spec dir mail (mail_probes dir mail)
