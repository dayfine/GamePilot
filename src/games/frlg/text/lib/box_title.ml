let white_min = 250
let white_max = 255
let frame_timeout_ms = 1000

let ink : Wire.color_range =
  {
    min = (white_min, white_min, white_min);
    max = (white_max, white_max, white_max);
  }

(* A sprite pair at x [176 - width / 2] (centre 16 in), y 28 (pokefirered
   pokemon_storage_system_graphics.c, [InitBoxTitle], [GetBoxTitleBaseX]),
   the text at its top left: centred on x 160, glyph cells from y 22. *)
let centre = 160
let glyph_top = 22
let margin = 2

let line_of_width width : Text_lines.t =
  {
    id = "pc_box_title";
    left = centre - (width / 2);
    indent = margin;
    glyph_top;
    width = width + (2 * margin);
  }

let line glyphs text =
  Result.map line_of_width (Text_drawing.text_width glyphs text)

let with_probes_await probes =
  let ids = List.map (fun (p : Wire.probe_spec) -> p.id) probes in
  let all_there m = List.for_all (fun id -> Effects.probe m id <> None) ids in
  Effects.with_probes probes (fun () ->
      Effects.await ~timeout_ms:frame_timeout_ms all_there)

let template glyphs text =
  Result.bind (line glyphs text) (fun l ->
      Result.map
        (fun png -> (l, png))
        (Line_reading.template ~ink glyphs l text))

let score glyphs m text =
  match line glyphs text with
  | Error _ -> None
  | Ok l -> (
      match Line_reading.pick ~max_score:Float.infinity l [ text ] m with
      | Read { score; _ } -> Some (text, score)
      | No_match _ -> None)

let pick glyphs candidates m : Line_reading.reading =
  let scored = List.filter_map (score glyphs m) candidates in
  match List.sort (fun (_, a) (_, b) -> Float.compare a b) scored with
  | (text, score) :: _ when score <= Line_reading.max_score ->
      Read { text; score }
  | (text, score) :: _ -> No_match { best = Some text; score }
  | [] -> No_match { best = None; score = Float.infinity }

let probe glyphs text =
  Result.map
    (fun (l, png) ->
      Line_reading.probe ~ink l text ~template:(Effects.upload_template png))
    (template glyphs text)

let probes glyphs candidates =
  List.fold_right
    (fun c acc ->
      Result.bind acc (fun ps -> Result.map (fun p -> p :: ps) (probe glyphs c)))
    candidates (Ok [])

let read glyphs candidates =
  Result.bind (probes glyphs candidates) (fun probes ->
      match with_probes_await probes with
      | Holds m -> Ok (pick glyphs candidates m)
      | Timeout -> Error "no frame with the box title's probes")
