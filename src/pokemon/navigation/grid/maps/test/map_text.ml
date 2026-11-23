(* A parsed map's values as text, for tests to compare with what the map
   file says, and the case shape the map tests share. *)

open Grid_maps
open Map_features
open Map_gates

let glyph_at (map : Map_data.t) x y =
  String.make 1 (Tile_kind.glyph (Grid.get map.tiles { x; y }))

let opt = Option.value ~default:"(none)"
let tiles list = String.concat "" (List.map Tile_pos.to_string list)

let entry = function
  | Walk_into -> "walk_into"
  | Step_on -> "step_on"
  | Cave_entrance -> "cave_entrance"
  | Walk d -> "walk_" ^ Direction.name d

let warp_at map x y =
  match Map_data.warp_at map { x; y } with
  | None -> "(none)"
  | Some w ->
      let goes =
        match w.destination with
        | Some d -> d.to_map ^ "." ^ d.to_point
        | None -> "(not in the set)"
      in
      Printf.sprintf "%s %s -> %s%s"
        (Tile_pos.to_string w.warp_pos)
        (entry w.enter) goes
        (if w.one_way then " one way" else "")

let trainer (map : Map_data.t) i =
  match (List.nth map.objects i).trainer with
  | None -> "(none)"
  | Some t ->
      Printf.sprintf "sight %d, looks %s" t.sight
        (String.concat " " (List.map Direction.name t.looks))

let box b = tiles [ b.top_left; b.bottom_right ]
let object_field (map : Map_data.t) i read = read (List.nth map.objects i)

let point (map : Map_data.t) name =
  Tile_pos.to_string (Map_data.String_map.find name map.points)

let elevation_at (map : Map_data.t) x y =
  string_of_int (Grid.get (Option.get map.elevation) { x; y })

let gate (map : Map_data.t) id =
  let g = Map_data.String_map.find id map.gates in
  let control =
    match g.control with
    | Flag { opener; flag } ->
        let opener =
          match opener with
          | Card_key -> "card key"
          | Quiz_answer -> "quiz"
          | Cut -> "cut"
          | Rock_smash -> "rock smash"
        in
        opener ^ " " ^ flag
    | Switch { switch_id; open_when_on } ->
        Printf.sprintf "switch %s open when %b" switch_id open_when_on
  in
  Printf.sprintf "%s, opens to '%c', new game %b" control
    (Tile_kind.glyph g.open_tile)
    g.open_at_new_game

let switch (map : Map_data.t) id =
  let s = Map_data.String_map.find id map.switches in
  let press =
    match s.press with
    | Statues l ->
        String.concat " "
          (List.map
             (fun st ->
               Tile_pos.to_string st.statue_tile
               ^ " " ^ Direction.name st.facing)
             l)
    | Boulder_buttons { buttons; set_value } ->
        Printf.sprintf "%s set %d" (tiles buttons) set_value
  in
  Printf.sprintf "%s on %s: %s" s.switch_flag (String.concat "," s.floors) press

type case = {
  name : string;
  input : string;  (** The map: its JSON, or its name in a map directory. *)
  expectation : (string * string * (Map_data.t -> string)) list;
      (** What is read, the text it should read as, and how to read it. *)
}

let count list = string_of_int (List.length list)

let flag_set (map : Map_data.t) name =
  String.concat " "
    (Map_data.String_set.elements (Map_data.String_map.find name map.flag_sets))

(* A map from a JSON text, named Test.json in errors. *)
let of_json input = Map_file.of_string ~source_name:"Test.json" input

(* Reads the case's map with [read_map] and checks each expectation. *)
let run_case ~read_map { name; input; expectation } =
  Check.report name
    (Result.bind (read_map input) (fun map ->
         Check.all
           (List.map
              (fun (what, expected, read) () ->
                Check.equal what ~expected (read map))
              expectation)))
