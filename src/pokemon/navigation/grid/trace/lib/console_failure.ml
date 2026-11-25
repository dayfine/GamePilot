open Grid_maps
open Grid_geometry

type fade = Unseen | Black | Dim | White

type overrun = {
  step : string;
  direction : Direction.t;
  tiles : int;
  fade : fade;
  far_pose_of : string option;
}

type fault =
  | Fade_missed of int
  | Banner_missed of int
  | Moved_further of overrun
  | Hold_through_warp of overrun
  | Scene_ends_further of overrun
  | Moved_less of { step : string; index : int; tiles : int }
  | Person_stands of { name : string; tile : Tile_pos.t }

let fault_kind_name = function
  | Fade_missed _ -> "fade_missed"
  | Banner_missed _ -> "banner_missed"
  | Moved_further _ -> "moved_further"
  | Hold_through_warp _ -> "hold_through_warp"
  | Scene_ends_further _ -> "scene_ends_further"
  | Moved_less _ -> "moved_less"
  | Person_stands _ -> "person_stands"

type t = {
  name : string;
  checkpoint : string;
  start : (Route_tile.t * Direction.t) option;
  faults : fault list;
  failed_step : string;
  failed_error : string;
  frame : string;
  evidence : string list;
}

let fade_of where = function
  | "unseen" -> Unseen
  | "black" -> Black
  | "dim" -> Dim
  | "white" -> White
  | text -> Json_field.fail "%sfade: unknown fade \"%s\"." where text

let int_or ~where ~default key obj =
  if Json_field.has key obj then Json_field.int ~where key obj else default

let overrun ~where obj =
  let fade =
    Option.value (Json_field.string_opt ~where "fade" obj) ~default:"unseen"
  in
  {
    step = Json_field.string ~where "step" obj;
    direction = Grid_field.direction ~where "direction" obj;
    tiles = int_or ~where ~default:1 "tiles" obj;
    fade = fade_of where fade;
    far_pose_of = Json_field.string_opt ~where "far_pose_of" obj;
  }

let tile_of ~where obj =
  Grid_field.pair (where ^ "tile") (Json_field.field ~where "tile" obj)

let fault ~where obj =
  let int key = Json_field.int ~where key obj in
  let string key = Json_field.string ~where key obj in
  match string "kind" with
  | "fade_missed" -> Fade_missed (int "index")
  | "banner_missed" -> Banner_missed (int "index")
  | "moved_further" -> Moved_further (overrun ~where obj)
  | "hold_through_warp" -> Hold_through_warp (overrun ~where obj)
  | "scene_ends_further" -> Scene_ends_further (overrun ~where obj)
  | "moved_less" ->
      Moved_less
        { step = string "step"; index = int "index"; tiles = int "tiles" }
  | "person_stands" ->
      Person_stands { name = string "name"; tile = tile_of ~where obj }
  | kind -> Json_field.fail "%skind: unknown fault kind \"%s\"." where kind

let start_of ~where start =
  let where = where ^ "start." in
  let tile = tile_of ~where start in
  ( { Route_tile.map = Json_field.string ~where "map" start; pos = tile },
    Grid_field.direction ~where "facing" start )

let start ~where obj =
  Option.map (start_of ~where) (Json_field.object_opt ~where "start" obj)

let evidence ~where obj =
  match Json_field.list_opt ~where "evidence" obj with
  | None -> []
  | Some lines -> Json_field.strings (where ^ "evidence") (`List lines)

(* Unlike Json_field.records, the list must be there, empty or not. *)
let faults ~where obj =
  ignore (Json_field.field ~where "faults" obj);
  Json_field.records ~where "faults" obj fault

let read ~name obj =
  let where = Printf.sprintf "console failure %s: " name in
  let failed =
    Json_field.as_object (where ^ "failed")
      (Json_field.field ~where "failed" obj)
  in
  let failed_where = where ^ "failed." in
  {
    name;
    checkpoint = Json_field.string ~where "checkpoint" obj;
    start = start ~where obj;
    faults = faults ~where obj;
    failed_step = Json_field.string ~where:failed_where "step" failed;
    failed_error = Json_field.string ~where:failed_where "error" failed;
    frame = Json_field.string ~where "frame" obj;
    evidence = evidence ~where obj;
  }

let parse ~name text =
  match Yojson.Safe.from_string text with
  | exception Yojson.Json_error why ->
      Error (Printf.sprintf "console failure %s: %s" name why)
  | json -> (
      try
        Ok (read ~name (Json_field.as_object ("console failure " ^ name) json))
      with Json_field.Invalid why -> Error why)
