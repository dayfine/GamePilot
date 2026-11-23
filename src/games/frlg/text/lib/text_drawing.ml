type rgb = { r : int; g : int; b : int }
type style = { text : rgb; shadow : rgb; background : rgb }
type image = { width : int; height : int; pixels : Bytes.t }

let bytes_per_pixel = 3

let chars text =
  let rec decode pos acc =
    if pos >= String.length text then List.rev acc
    else
      let d = String.get_utf_8_uchar text pos in
      decode (pos + Uchar.utf_decode_length d) (Uchar.utf_decode_uchar d :: acc)
  in
  decode 0 []

let glyph_of glyphs text char =
  match Glyph_table.find glyphs char with
  | Some g -> Ok g
  | None ->
      Error
        (Printf.sprintf "no glyph for U+%04X in %S" (Uchar.to_int char) text)

let glyphs_of glyphs text =
  List.fold_right
    (fun char acc ->
      Result.bind acc (fun gs ->
          Result.map (fun g -> g :: gs) (glyph_of glyphs text char)))
    (chars text) (Ok [])

let total_width gs =
  List.fold_left (fun w (g : Glyph_table.glyph) -> w + g.width) 0 gs

let text_width glyphs text = Result.map total_width (glyphs_of glyphs text)

let set_pixel image x y { r; g; b } =
  let at = ((y * image.width) + x) * bytes_per_pixel in
  Bytes.set_uint8 image.pixels at r;
  Bytes.set_uint8 image.pixels (at + 1) g;
  Bytes.set_uint8 image.pixels (at + 2) b

let color style : Glyph_table.pixel -> rgb = function
  | Background -> style.background
  | Text -> style.text
  | Shadow -> style.shadow

let blank style ~width ~height =
  let image =
    { width; height; pixels = Bytes.create (width * height * bytes_per_pixel) }
  in
  for y = 0 to height - 1 do
    for x = 0 to width - 1 do
      set_pixel image x y style.background
    done
  done;
  image

let draw_glyph image style ~top ~left (g : Glyph_table.glyph) =
  for y = 0 to image.height - 1 do
    Array.iteri
      (fun x pixel -> set_pixel image (left + x) y (color style pixel))
      g.rows.(top + y)
  done

let draw glyphs style ~width ~indent ~top ~height text =
  match glyphs_of glyphs text with
  | Error _ as e -> e
  | Ok gs when indent + total_width gs > width ->
      Error (Printf.sprintf "%S is wider than %d pixels" text width)
  | Ok gs ->
      let image = blank style ~width ~height in
      let draw_at left (g : Glyph_table.glyph) =
        draw_glyph image style ~top ~left g;
        left + g.width
      in
      ignore (List.fold_left draw_at indent gs);
      Ok image
