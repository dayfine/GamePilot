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

let uploaded glyphs candidates =
  let probes = List.map (upload glyphs) candidates in
  let ids = List.map (fun (p : Wire.probe_spec) -> p.id) probes in
  (probes, fun m -> List.for_all (fun id -> Effects.probe m id <> None) ids)

let read glyphs candidates =
  let probes, all_there = uploaded glyphs candidates in
  match
    Effects.with_probes probes (fun () ->
        Effects.await ~timeout_ms:frame_timeout_ms all_there)
  with
  | Holds m -> pick glyphs candidates m
  | Timeout -> failwith "no frame with the mail field's probes"

let nothing : Line_reading.reading =
  No_match { best = None; score = Float.infinity }

let await_read glyphs candidates ~timeout_ms =
  let probes, all_there = uploaded glyphs candidates in
  let reads m =
    all_there m
    &&
    match pick glyphs candidates m with Read _ -> true | No_match _ -> false
  in
  Effects.with_probes probes (fun () ->
      match Effects.await ~timeout_ms reads with
      | Holds m -> pick glyphs candidates m
      | Timeout -> (
          match Effects.read () with
          | Some m when all_there m -> pick glyphs candidates m
          | _ -> nothing))

let first_left = 41

let next_left glyphs ~left text =
  Result.map (fun w -> left + w + gap) (Text_drawing.text_width glyphs text)

let field_line glyphs ~row ~left text =
  Result.map
    (fun width -> Text_lines.mail_field ~row ~left ~width:(width + gap))
    (Text_drawing.text_width glyphs text)

let line_probe line text png =
  (line, Line_reading.probe line text ~template:(Effects.upload_template png))

let field_probe glyphs ~row ~left text =
  Result.bind (field_line glyphs ~row ~left text) (fun line ->
      Result.map (line_probe line text) (Line_reading.template glyphs line text))

let score m (c, (line, _)) =
  match Line_reading.pick ~max_score:Float.infinity line [ c ] m with
  | Line_reading.Read { score; _ } -> Some (c, score)
  | No_match _ -> None

(* The best candidate of one frame, if it scores within the reading's limit. *)
let best m ok =
  let scored = List.filter_map (score m) ok in
  match List.sort (fun (_, a) (_, b) -> Float.compare a b) scored with
  | (text, score) :: _ when score <= Line_reading.max_score ->
      Line_reading.Read { text; score }
  | (text, score) :: _ -> No_match { best = Some text; score }
  | [] -> nothing

let first_error made =
  List.find_map
    (fun (_, r) -> Result.fold ~ok:(fun _ -> None) ~error:Option.some r)
    made

let await_best ok =
  let probes = List.map (fun (_, (_, p)) -> p) ok in
  let all_there m =
    List.for_all
      (fun (p : Wire.probe_spec) -> Effects.probe m p.id <> None)
      probes
  in
  Effects.with_probes probes (fun () ->
      match Effects.await ~timeout_ms:frame_timeout_ms all_there with
      | Holds m -> Ok (best m ok)
      | Timeout -> Error "no frame with the mail field's probes")

let read_field glyphs ~row ~left candidates =
  let made =
    List.map (fun c -> (c, field_probe glyphs ~row ~left c)) candidates
  in
  match first_error made with
  | Some why -> Error why
  | None ->
      await_best
        (List.filter_map
           (fun (c, r) -> Option.map (fun lp -> (c, lp)) (Result.to_option r))
           made)
