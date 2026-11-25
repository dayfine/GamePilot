(* Word drawing: a known word's mask, row by row, against a committed bitmap
   ('#' ink, '.' paper) checked by eye against the game's font. *)

open Frlg_text

let glyphs =
  match Data_files.locate Data_files.glyph_table with
  | Some path -> Glyph_table.load path
  | None -> failwith "glyph table not found"

let is_ink (image : Text_drawing.image) x y =
  let at = ((y * image.width) + x) * 3 in
  let channel i = Bytes.get_uint8 image.pixels (at + i) in
  let ink = Text_drawing.ink in
  channel 0 = ink.r && channel 1 = ink.g && channel 2 = ink.b

let bitmap (image : Text_drawing.image) =
  List.init image.height (fun y ->
      String.init image.width (fun x -> if is_ink image x y then '#' else '.'))

let expected =
  In_channel.with_open_bin "fixtures/mask_HM_indent2.txt" In_channel.input_all
  |> String.split_on_char '\n'
  |> List.filter (fun s -> s <> "")

let drawn () =
  match
    Text_drawing.draw_mask glyphs ~width:16 ~indent:2
      ~top:Text_lines.template_top ~height:Text_lines.template_height "HM"
  with
  | Ok image -> bitmap image
  | Error why -> failwith why

let () =
  Table_test.run "text_drawing"
    [
      {
        Table_test.name = "HM, indent 2, width 16";
        input = (fun () -> String.concat "\n" (drawn ()));
        expectation = String.concat "\n" expected;
      };
    ]
