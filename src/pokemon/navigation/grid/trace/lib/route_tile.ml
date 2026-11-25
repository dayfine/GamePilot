open Grid_geometry

type t = { map : string; pos : Tile_pos.t }

let to_string tile = tile.map ^ " " ^ Tile_pos.to_string tile.pos

let describe = function
  | [] -> "an unknown tile"
  | tiles -> String.concat ", " (List.map to_string tiles)

(* "Route 202 (23, 25)": the map is everything before the last " (". *)
let parse text =
  let n = String.length text in
  match (Log_text.rfind text " (", Log_text.rfind text ", ") with
  | Some opening, Some comma
    when opening > 0 && comma > opening && String.ends_with ~suffix:")" text
    -> (
      let x = Log_text.int (Log_text.slice text (opening + 2) comma) in
      let y = Log_text.int (Log_text.slice text (comma + 2) (n - 1)) in
      match (x, y) with
      | Some x, Some y ->
          Some { map = String.sub text 0 opening; pos = { x; y } }
      | _ -> None)
  | _ -> None

(* Each tile ends at its ")"; ", " separates them. *)
let parse_list text =
  let n = String.length text in
  let rec from i tiles =
    if i >= n then List.rev tiles
    else
      match String.index_from_opt text i ')' with
      | None -> []
      | Some close -> (
          match parse (Log_text.slice text i (close + 1)) with
          | None -> []
          | Some tile -> after (close + 1) (tile :: tiles))
  and after i tiles =
    if i >= n then List.rev tiles
    else if Log_text.is_at text i ", " then from (i + 2) tiles
    else []
  in
  from 0 []
