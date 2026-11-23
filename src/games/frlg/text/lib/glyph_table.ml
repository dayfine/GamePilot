type pixel = Background | Text | Shadow
type glyph = { width : int; rows : pixel array array }
type t = (Uchar.t, glyph) Hashtbl.t

let glyph_height = 14

let pixel_of_char = function
  | '.' -> Background
  | '#' -> Text
  | 's' -> Shadow
  | c -> failwith (Printf.sprintf "glyph pixel %C" c)

let row_of_string width s =
  if String.length s <> width then failwith ("glyph row " ^ s);
  Array.init width (fun i -> pixel_of_char s.[i])

let glyph_of_fields width rows =
  let rows = String.split_on_char '/' rows in
  if List.length rows <> glyph_height then failwith "glyph height";
  { width; rows = Array.of_list (List.map (row_of_string width) rows) }

let entry line =
  match String.split_on_char ' ' line with
  | [ _code; width; codepoint; rows ] ->
      ( Uchar.of_int (int_of_string ("0x" ^ codepoint)),
        glyph_of_fields (int_of_string width) rows )
  | _ -> failwith ("glyph line " ^ line)

let add_line table line =
  let comment = line = "" || line.[0] = '#' in
  if not comment then
    let char, glyph = entry line in
    if not (Hashtbl.mem table char) then Hashtbl.replace table char glyph

let expected_glyphs = 256

let of_string text =
  let table = Hashtbl.create expected_glyphs in
  List.iter (add_line table) (String.split_on_char '\n' text);
  table

let load path = of_string (In_channel.with_open_bin path In_channel.input_all)
let find = Hashtbl.find_opt
