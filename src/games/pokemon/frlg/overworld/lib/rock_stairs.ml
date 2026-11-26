open Grid_geometry
module Tiles = Set.Make (Tile_pos)
module Maps = Map.Make (String)

type t = Tiles.t Maps.t

let none = Maps.empty
let asset = "src/games/pokemon/frlg/assets/rock_stairs.txt"

let tile_of word =
  match String.split_on_char ',' word with
  | [ x; y ] -> (
      match (int_of_string_opt x, int_of_string_opt y) with
      | Some x, Some y -> Ok { Tile_pos.x; y }
      | _ -> Error word)
  | _ -> Error word

let add_tile map acc word =
  Result.bind acc (fun tiles ->
      match tile_of word with
      | Ok tile -> Ok (Tiles.add tile tiles)
      | Error bad ->
          Error (Printf.sprintf "rock stairs: %s: bad tile %S" map bad))

let is_comment word = String.length word > 0 && word.[0] = '#'

let parse_line stairs line =
  match String.split_on_char ' ' (String.trim line) with
  | [] | [ "" ] -> Ok stairs
  | word :: _ when is_comment word -> Ok stairs
  | map :: words ->
      List.fold_left (add_tile map) (Ok Tiles.empty) words
      |> Result.map (fun tiles -> Maps.add map tiles stairs)

let parse text =
  List.fold_left
    (fun acc line -> Result.bind acc (fun stairs -> parse_line stairs line))
    (Ok none)
    (String.split_on_char '\n' text)

let load path =
  match In_channel.with_open_bin path In_channel.input_all with
  | text -> parse text
  | exception Sys_error e -> Error e

let on stairs ~map tile =
  match Maps.find_opt map stairs with
  | Some tiles -> Tiles.mem tile tiles
  | None -> false
