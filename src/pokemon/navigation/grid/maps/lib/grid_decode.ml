open Json_field

(* The rows as strings of [width] characters; [what] says what a row holds. *)
let row_strings ~where ~key ~width ~what values =
  let row y : Yojson.Safe.t -> string = function
    | `String text when String.length text = width -> text
    | _ -> fail "%s%s[%d] is not a string of %d %s." where key y width what
  in
  Array.of_list (List.mapi row values)

(* A grid from the rows, each character read by [cell row_where pos char]. *)
let grid_of_rows ~where ~key ~width lines cell =
  Grid.init ~width ~height:(Array.length lines)
    (fun ({ x; y } as pos : Tile_pos.t) ->
      cell (Printf.sprintf "%s%s[%d]" where key y) pos lines.(y).[x])

let tile_cell row_where pos glyph =
  match Tile_kind.of_glyph glyph with
  | Some tile -> tile
  | None ->
      fail "%s has unknown glyph '%c' at %s." row_where glyph
        (Tile_pos.to_string pos)

let tiles ~where obj =
  let values =
    match field ~where "tiles" obj with
    | `List [] -> fail "%stiles has no rows." where
    | `List values -> values
    | _ -> fail "%stiles is not an array." where
  in
  let width =
    match values with
    | `String first :: _ when first <> "" -> String.length first
    | _ -> fail "%stiles[0] is not a string of glyphs." where
  in
  let lines = row_strings ~where ~key:"tiles" ~width ~what:"glyphs" values in
  grid_of_rows ~where ~key:"tiles" ~width lines tile_cell

let hex_digits = "0123456789abcdef"

let level_cell row_where pos digit =
  match String.index_opt hex_digits digit with
  | Some level -> level
  | None ->
      fail "%s has '%c' at %s, not a hex digit (0-9, a-f)." row_where digit
        (Tile_pos.to_string pos)

let elevation ~where ~width ~height obj =
  match list_opt ~where "elevation" obj with
  | None -> None
  | Some values ->
      let rows = List.length values in
      if rows <> height then
        fail "%selevation has %d rows, not the tiles' %d." where rows height;
      let lines =
        row_strings ~where ~key:"elevation" ~width ~what:"hex digits" values
      in
      Some (grid_of_rows ~where ~key:"elevation" ~width lines level_cell)
