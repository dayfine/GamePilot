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
let items = Item_names.load (required Data_files.item_names_eng)

let tm_moves =
  Tm_moves.names (Tm_moves.load (required Data_files.tm_hm_moves_eng))

let moves =
  List.map snd
    (Move_names.load ~language:"eng" (required Data_files.move_names))

let rows n line = List.init n line

let species =
  List.map snd (Species_names.load (required Data_files.species_names_eng))

let dark = Line_reading.ink

(* Each screen: its lines, their candidates and the ink they are read in. *)
let screens =
  [
    ( "bag_items",
      rows 6 Text_lines.bag_row,
      Item_names.in_pocket items Items @ [ "CANCEL" ],
      dark );
    ( "bag_key_items",
      rows 6 Text_lines.bag_row,
      Item_names.in_pocket items Key_items @ [ "CANCEL" ],
      dark );
    ("tm_case", rows 5 Text_lines.tm_case_row, tm_moves, dark);
    ("summary_moves", rows 4 Text_lines.summary_move, moves, dark);
    ( "battle_opening",
      [ Text_lines.battle_message 0 ],
      List.map (fun name -> "Wild " ^ name ^ " appeared!") species,
      Line_reading.light_ink );
  ]

let write_file path data =
  Out_channel.with_open_bin path (fun oc -> output_string oc data)

let line_probes dir screen ink line candidates =
  List.filteri
    (fun _ text -> Result.is_ok (Line_reading.template ~ink glyphs line text))
    candidates
  |> List.mapi (fun i text ->
         match Line_reading.template ~ink glyphs line text with
         | Error why -> failwith why
         | Ok png ->
             let name =
               Printf.sprintf "%s/%s.%d.png" screen line.Text_lines.id i
             in
             write_file (Filename.concat dir name) png;
             Line_reading.probe ~ink line text ~template:name)

let write_screen dir (screen, lines, candidates, ink) =
  let sub = Filename.concat dir screen in
  if not (Sys.file_exists sub) then Sys.mkdir sub 0o755;
  let probes =
    List.concat_map
      (fun line -> line_probes dir screen ink line candidates)
      lines
  in
  let request =
    Wire.json_of_message (Request { id = 1; call = Subscribe probes })
  in
  write_file
    (Filename.concat dir (screen ^ ".json"))
    (Yojson.Safe.to_string (Yojson.Safe.Util.member "params" request))

let () =
  let dir = Sys.argv.(1) in
  List.iter (write_screen dir) screens
