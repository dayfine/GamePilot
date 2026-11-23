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
    "bag_counts";
    "berry_pouch_numbers";
    "mail_editor";
  ]

let glyphs =
  match Data_files.locate Data_files.glyph_table with
  | Some path -> Glyph_table.load path
  | None -> failwith "glyph table not found"

(* The mail editor's field: each candidate on a line of its own width. *)
let mail_field = "mail_field.1"

(* A line and the score its reader allows: small-font digits have their own. *)
let line_of_id id =
  let normal line = (line, Line_reading.max_score)
  and small line = (line, Number_reading.small_max_score) in
  match String.split_on_char '.' id with
  | [ "bag"; i ] -> normal (Text_lines.bag_row (int_of_string i))
  | [ "tm_case"; i ] -> normal (Text_lines.tm_case_row (int_of_string i))
  | [ "summary_move"; i ] -> normal (Text_lines.summary_move (int_of_string i))
  | [ "bag_count"; row; k ] ->
      small (Text_lines.bag_count_digit (int_of_string row) (int_of_string k))
  | [ "pouch_number"; row; k ] ->
      small
        (Text_lines.berry_pouch_number_digit (int_of_string row)
           (int_of_string k))
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
  Case_table.run "text_reading"
    (List.map
       (fun e ->
         {
           Case_table.name = e.image ^ " " ^ e.line;
           input = (fun () -> reading e);
           expectation = e.reads;
         })
       expectations)
