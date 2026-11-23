type reading =
  | Read of { text : string; score : float }
  | No_match of { best : string option; score : float }

let max_score = 0.024
let frame_timeout_ms = 1000
let darkest = 0
let text_red_green_max = 144
let any_blue = 255

let ink : Wire.color_range =
  {
    min = (darkest, darkest, darkest);
    max = (text_red_green_max, text_red_green_max, any_blue);
  }

let light_min = 200
let brightest = 255

let light_ink : Wire.color_range =
  {
    min = (light_min, light_min, light_min);
    max = (brightest, brightest, brightest);
  }

let template glyphs (line : Text_lines.t) text =
  Text_drawing.draw_mask glyphs ~width:line.width ~indent:line.indent
    ~top:Text_lines.template_top ~height:Text_lines.template_height text
  |> Result.map Png_encoding.encode_rgb

let probe_id (line : Text_lines.t) text = line.id ^ "/" ^ text

let probe ?(ink = ink) line text ~template =
  Wire.template_match_probe ~ink ~id:(probe_id line text)
    ~box:(Text_lines.box line) ~delivery:Latest ~template ()

let score line m text =
  match Effects.probe m (probe_id line text) with
  | Some (Wire.Template_match { score; _ }) -> Some (text, score)
  | _ -> None

let pick line candidates m =
  let scored = List.filter_map (score line m) candidates in
  match List.sort (fun (_, a) (_, b) -> Float.compare a b) scored with
  | (text, score) :: _ when score <= max_score -> Read { text; score }
  | (text, score) :: _ -> No_match { best = Some text; score }
  | [] -> No_match { best = None; score = Float.infinity }

let upload ?ink glyphs line text =
  match template glyphs line text with
  | Ok png -> probe ?ink line text ~template:(Effects.upload_template png)
  | Error why -> invalid_arg why

let probes ?ink glyphs line candidates =
  List.map (upload ?ink glyphs line) candidates

let read glyphs line candidates =
  let probes = probes glyphs line candidates in
  let ids = List.map (fun (p : Wire.probe_spec) -> p.id) probes in
  let all_there m = List.for_all (fun id -> Effects.probe m id <> None) ids in
  match
    Effects.with_probes probes (fun () ->
        Effects.await ~timeout_ms:frame_timeout_ms all_there)
  with
  | Holds m -> pick line candidates m
  | Timeout -> failwith ("no frame with the probes of " ^ line.id)
