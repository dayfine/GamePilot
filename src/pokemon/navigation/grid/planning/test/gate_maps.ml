(* FireRed's gate maps from the PokemonSimulation submodule (Silph Co. 5F:
   Card Key doors; Pokemon Mansion 1F and 3F: a statue switch, barriers,
   holes), and a step model that walks them with the gates as the state
   says. The C++ fork's tests read the same maps trimmed (its copies match
   these, except that 3F's holes are tall grass there). *)

open Grid_maps
open Grid_geometry
open Grid_planning

(* third_party/ sits outside the dune project, so find it from the build
   dir. *)
let maps_dir =
  let maps =
    List.fold_left Filename.concat "third_party"
      [ "PokemonSimulation"; "data"; "games"; "frlg"; "maps" ]
  in
  let rec up dir =
    let candidate = Filename.concat dir maps in
    if Sys.file_exists candidate then candidate
    else
      let parent = Filename.dirname dir in
      if parent = dir then
        failwith "third_party/PokemonSimulation not found above the test dir"
      else up parent
  in
  up (Sys.getcwd ())

let load name = Result.get_ok (Map_file.load_runtime ~maps_dir name)

let world =
  Connected_maps.create
    (List.map load [ "SilphCo_5F"; "PokemonMansion_1F"; "PokemonMansion_3F" ])

let silph = 0
let mansion_1f = 1
let mansion_3f = 2
let place map x y = { Connected_maps.map; tile = { x; y } }

let walkable = function
  | Tile_kind.Open | Tall_grass | Fall_hole -> true
  | _ -> false

let open_ahead gates (place : Connected_maps.place) direction =
  let map = Connected_maps.map world place.map in
  let next = Tile_pos.next place.tile direction in
  if
    Grid.contains map.tiles next
    && walkable (Gate_tiles.resolved_tile map gates next)
  then Some (map, next)
  else None

(* A step onto a step-on warp takes it; one that leads nowhere here is
   refused. Walk-into warps are not modelled: they are not the topic. *)
let press (place : Connected_maps.place) direction gates =
  let step_to (map, next) =
    let step = Leg.plain_step { place with tile = next } direction in
    match Map_data.warp_at map next with
    | Some ({ enter = Step_on; _ } as warp) ->
        Connected_maps.warp_arrival world warp
        |> Option.map (fun arrival ->
               { step with next = arrival; warped = true; ends_leg = true })
    | _ -> Some step
  in
  Option.bind (open_ahead gates place direction) step_to

let held_at place direction gates =
  Option.is_none (open_ahead gates place direction)

let game =
  Gated_model.simple_game ~compare_inner:Connected_maps.compare_place ~press
    ~held_at ~place_of:Fun.id

(* A synthetic map read from JSON text. *)
let of_json name text =
  match Map_file.of_string ~source_name:(name ^ ".json") text with
  | Ok map -> map
  | Error e -> failwith e
