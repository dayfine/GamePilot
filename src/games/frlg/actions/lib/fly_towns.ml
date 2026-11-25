module J = Json_field

type town = {
  name : string;
  cell : Grid_maps.Tile_pos.t;
  landing : Checkpoints_plan.Pose.observed;
}

type t = { columns : int; rows : int; towns : town list }

(* pokefirered src/field_effect.c, FlyInFieldEffect_End: the player gets off
   the bird turned south. *)
let landing_facing = Grid_maps.Direction.South
let asset = "src/games/frlg/assets/kanto_fly_towns.json"

let tile ~where key obj : Grid_maps.Tile_pos.t =
  match J.field ~where key obj with
  | `List [ `Int x; `Int y ] -> { x; y }
  | _ -> J.fail "%s%s is not [x, y]." where key

let town i json =
  let where = J.item_where "kanto_fly_towns.json: " "towns" i in
  let obj = J.as_object where json in
  let landing = J.as_object where (J.field ~where "landing" obj) in
  {
    name = J.string ~where "name" obj;
    cell = tile ~where "cell" obj;
    landing =
      {
        at_map = J.string ~where "map" landing;
        at_tile = tile ~where "tile" landing;
        faces = Some landing_facing;
      };
  }

let parse json =
  let where = "kanto_fly_towns.json: " in
  match
    let obj = J.as_object where json in
    let towns = Option.value (J.list_opt ~where "towns" obj) ~default:[] in
    {
      columns = J.int ~where "columns" obj;
      rows = J.int ~where "rows" obj;
      towns = List.mapi town towns;
    }
  with
  | table -> Ok table
  | exception J.Invalid e -> Error e

let read () =
  match Repo_io.Repo_files.locate asset with
  | None -> Error (asset ^ " not found from the working directory")
  | Some path -> (
      match Yojson.Safe.from_file path with
      | json -> parse json
      | exception Yojson.Json_error e -> Error (path ^ ": " ^ e))

let table = lazy (read ())
let load () = Lazy.force table
let find t name = List.find_opt (fun town -> town.name = name) t.towns

(* A cursor step takes 4 frames; the release lets it stop. Up-left to the
   corner: 21 cells at 4 frames is 1.4 s. *)
let cursor_tap_ms = 80
let cursor_release_ms = 170
let to_corner_ms = 3000

let taps button n =
  let tap =
    Wire.Press
      {
        buttons = [ button ];
        hold_ms = cursor_tap_ms;
        cooldown_ms = cursor_release_ms;
      }
  in
  List.init n (fun _ -> tap)

let cursor_presses town =
  Wire.Press
    {
      buttons = [ Wire.Up; Wire.Left ];
      hold_ms = to_corner_ms;
      cooldown_ms = cursor_release_ms;
    }
  :: (taps Wire.Right town.cell.x @ taps Wire.Down town.cell.y)
