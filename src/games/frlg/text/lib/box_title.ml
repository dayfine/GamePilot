(* Under the title bars' darkest other colour, (0, 24, 99) on Seafloor and
   (82, 90, 99) on City, over the Switch's outline, which its scaling rings up
   to about 100 inside a stroke (mGBA draws it (57, 57, 57)). *)
let shadow_max = 98
let frame_timeout_ms = 1000

let ink : Wire.color_range =
  { min = (0, 0, 0); max = (shadow_max, shadow_max, shadow_max) }

let max_score = 0.006

(* A sprite pair at x [176 - width / 2] (centre 16 in), y 28 (pokefirered
   pokemon_storage_system_graphics.c, [InitBoxTitle], [GetBoxTitleBaseX]),
   the text at its top left: centred on x 160, glyph cells from y 22. *)
let centre = 160
let glyph_top = 22
let margin = 10

(* The template starts on an even game x and y: the Switch draws game pixel k
   of the GBA picture from frame pixel 180 + 6.5k across (5 + 6.5k down), a
   whole frame pixel only for an even k, and the daemon places a template on
   whole frame pixels. From an odd one, every edge of the drawing would sit
   half a frame pixel off the capture's. A name of odd left gets one more
   blank column on its left. *)
let parity x = x land 1

let line_of_width width : Text_lines.t =
  let left = centre - (width / 2) in
  let indent = margin + parity (left - margin) in
  {
    id = "pc_box_title";
    left;
    indent;
    glyph_top;
    width = width + indent + margin;
  }

let line glyphs text =
  Result.map line_of_width (Text_drawing.text_width glyphs text)

(* Glyph rows 0-11 (y 22-33): from row 0, an even y (see [line_of_width]);
   not row 12, since the title bar's dark frame runs along y 34 on some
   wallpapers (Desert), where it would put blank template pixels over it. *)
let rows_top = 0
let rows = 12
let slack = 2
let game_width = 240.
let game_height = 160.

let box (l : Text_lines.t) : Wire.box =
  {
    x = float (l.left - l.indent - slack) /. game_width;
    y = float (l.glyph_top + rows_top - slack) /. game_height;
    w = float (l.width + (2 * slack)) /. game_width;
    h = float (rows + (2 * slack)) /. game_height;
  }

let template glyphs text =
  Result.bind (line glyphs text) (fun l ->
      Text_drawing.draw_mask ~layer:Shadow glyphs ~width:l.width
        ~indent:l.indent ~top:rows_top ~height:rows text
      |> Result.map (fun image -> (l, Png_encoding.encode_rgb image)))

let probe_of (l : Text_lines.t) text ~template =
  Wire.template_match_probe ~ink ~skip_seams:true
    ~id:(Line_reading.probe_id l text)
    ~box:(box l) ~delivery:Latest ~template ()

let score glyphs m text =
  match line glyphs text with
  | Error _ -> None
  | Ok l -> (
      match Effects.probe m (Line_reading.probe_id l text) with
      | Some (Wire.Template_match { score; _ }) -> Some (text, score)
      | _ -> None)

let pick glyphs candidates m : Line_reading.reading =
  let scored = List.filter_map (score glyphs m) candidates in
  match List.sort (fun (_, a) (_, b) -> Float.compare a b) scored with
  | (text, score) :: _ when score <= max_score -> Read { text; score }
  | (text, score) :: _ -> No_match { best = Some text; score }
  | [] -> No_match { best = None; score = Float.infinity }

let probe glyphs text =
  Result.map
    (fun (l, png) -> probe_of l text ~template:(Effects.upload_template png))
    (template glyphs text)

let probes glyphs candidates =
  List.fold_right
    (fun c acc ->
      Result.bind acc (fun ps -> Result.map (fun p -> p :: ps) (probe glyphs c)))
    candidates (Ok [])

let with_probes_await probes =
  let ids = List.map (fun (p : Wire.probe_spec) -> p.id) probes in
  let all_there m = List.for_all (fun id -> Effects.probe m id <> None) ids in
  Effects.with_probes probes (fun () ->
      Effects.await ~timeout_ms:frame_timeout_ms all_there)

let read glyphs candidates =
  Result.bind (probes glyphs candidates) (fun probes ->
      match with_probes_await probes with
      | Holds m -> Ok (pick glyphs candidates m)
      | Timeout -> Error "no frame with the box title's probes")
