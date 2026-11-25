(* FireRed's maps from the PokemonSimulation submodule, for the route tests,
   and a one-line text of planned legs. *)

open Grid_maps
open Grid_geometry
open Grid_planning

(* third_party/ and src/games/frlg/assets sit outside the test's build dir,
   so find them from it. *)
let above path =
  let rec up dir =
    let candidate = Filename.concat dir path in
    if Sys.file_exists candidate then candidate
    else
      let parent = Filename.dirname dir in
      if parent = dir then failwith (path ^ " not found above the test dir")
      else up parent
  in
  up (Sys.getcwd ())

let maps_dir = above "third_party/PokemonSimulation/data/games/frlg/maps"

let rock_stairs =
  match
    Frlg_overworld.Rock_stairs.load (above Frlg_overworld.Rock_stairs.asset)
  with
  | Ok stairs -> stairs
  | Error e -> failwith e

let load name =
  match Map_file.load_runtime ~maps_dir name with
  | Ok map -> map
  | Error e -> failwith e

let world ?edge_stalls ?rock_stairs ?hidden names =
  Frlg_overworld.Frlg_steps.world ?edge_stalls ?rock_stairs ?hidden
    (Connected_maps.create (List.map load names))

(* mGBA's world, as the checkpoint runner loads it. *)
let mgba_world names =
  world ~edge_stalls:false ~rock_stairs
    ~hidden:(fun o ->
      Frlg_overworld.Scene_only_people.hidden o
      || Frlg_overworld.Scene_removed_people.hidden o)
    names

let pallet =
  world
    [
      "PalletTown";
      "PalletTown_PlayersHouse_1F";
      "PalletTown_PlayersHouse_2F";
      "Route1";
      "ViridianCity";
    ]

let place (w : Frlg_overworld.Frlg_steps.world) map x y =
  {
    Connected_maps.map = Option.get (Connected_maps.find w.maps map);
    tile = { x; y };
  }

let place_text (w : Frlg_overworld.Frlg_steps.world) (p : Connected_maps.place)
    =
  (Connected_maps.map w.maps p.map).name ^ " " ^ Tile_pos.to_string p.tile

let leg_text w (leg : Connected_maps.place Leg.t) =
  let kind =
    match leg.kind with
    | Walk { tiles; to_wall } ->
        Printf.sprintf "%s %d%s"
          (Direction.name leg.direction)
          tiles
          (if to_wall then " (to wall)" else "")
    | Face -> "face " ^ Direction.name leg.direction
    | Special_step _ -> "action " ^ Direction.name leg.direction
  in
  Printf.sprintf "%s%s -> %s %s" kind
    (if leg.warps then " (warp)" else "")
    (place_text w leg.finish)
    (Direction.name leg.facing_after)

let legs_text w = function
  | Ok legs -> String.concat "; " (List.map (leg_text w) legs)
  | Error e -> "error: " ^ e
