(* The text reader on real screenshots. The fixtures are the daemon's
   [probe_images] output for the specs write_text_probe_spec.exe writes (one
   per screen), over the images expected.txt names; the images stay out of the
   repo. Image paths start with their source: switch_clt (the fork's
   CommandLineTests/PokemonFRLG), switch_lab (~/FRLGLab/captures/summary-20261102)
   and mgba (~/FRLGLab/mgba/mail-glitch-04-inspect.u8fIqr). To make them again,
   with the images linked under those names in the current directory:

     dune exec games/frlg/text/test/write_text_probe_spec.exe -- <spec dir>
     probe_images --spec <spec dir>/<screen>.json \
       --viewport 0.09375,0.00462963,0.8125,0.962963 <switch images> \
       > fixtures/<screen>.probes.jsonl

   and the mGBA images appended without [--viewport]. *)

open Frlg_text

let screens = [ "bag_items"; "bag_key_items"; "tm_case"; "summary_moves" ]

let line_of_id id =
  match String.split_on_char '.' id with
  | [ "bag"; i ] -> Text_lines.bag_row (int_of_string i)
  | [ "tm_case"; i ] -> Text_lines.tm_case_row (int_of_string i)
  | [ "summary_move"; i ] -> Text_lines.summary_move (int_of_string i)
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

(* The candidates are the line's probes in the frame: the spec drew them. *)
let reading (e : expectation) =
  let probes = List.assoc e.image frames in
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
  match Line_reading.pick (line_of_id e.line) candidates m with
  | Read { text; _ } -> text
  | No_match _ -> "-"

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
