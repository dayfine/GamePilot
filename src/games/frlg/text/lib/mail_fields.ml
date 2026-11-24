let blank = String.make 7 '_'
let unknown_word = "???"
let gap = 17

let line glyphs text =
  match Text_drawing.text_width glyphs text with
  | Ok width -> Text_lines.mail_field_one ~width:(width + gap)
  | Error why -> invalid_arg why

(* The candidate's score on its own line, whatever it is. *)
let score glyphs m text =
  match
    Line_reading.pick ~max_score:Float.infinity (line glyphs text) [ text ] m
  with
  | Read { score; _ } -> Some (text, score)
  | No_match _ -> None

let pick glyphs candidates m : Line_reading.reading =
  let scored = List.filter_map (score glyphs m) candidates in
  match List.sort (fun (_, a) (_, b) -> Float.compare a b) scored with
  | (text, score) :: _ when score <= Line_reading.max_score ->
      Read { text; score }
  | (text, score) :: _ -> No_match { best = Some text; score }
  | [] -> No_match { best = None; score = Float.infinity }

let frame_timeout_ms = 1000

let upload glyphs text =
  let line = line glyphs text in
  match Line_reading.template glyphs line text with
  | Ok png ->
      Line_reading.probe line text ~template:(Effects.upload_template png)
  | Error why -> invalid_arg why

let read glyphs candidates =
  let probes = List.map (upload glyphs) candidates in
  let ids = List.map (fun (p : Wire.probe_spec) -> p.id) probes in
  let all_there m = List.for_all (fun id -> Effects.probe m id <> None) ids in
  match
    Effects.with_probes probes (fun () ->
        Effects.await ~timeout_ms:frame_timeout_ms all_there)
  with
  | Holds m -> pick glyphs candidates m
  | Timeout -> failwith "no frame with the mail field's probes"
