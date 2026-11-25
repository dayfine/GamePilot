(* Every spot a wild battle is paced for on (Frlg_actions.Paced_battle and the
   capture): the patch's tile and the one a step [pace] from it are both grass
   on PokemonSimulation's map, so pacing never leaves the grass (07-glitch-prep testing
   1 turned off it). The grind's spots come from its strategies; a plan's patch
   is where the event before a capture or PP drain leaves the player. *)

open Frlg_checkpoints

let case name input expectation = { Table_test.name; input; expectation }
let world = lazy (Result.get_ok (Checkpoint_run.load_world ()))

let kind map tile =
  let maps = (Lazy.force world).Frlg_overworld.Frlg_steps.maps in
  match Grid_maps.Connected_maps.find maps map with
  | None -> "no map " ^ map
  | Some i -> (
      let data = Grid_maps.Connected_maps.map maps i in
      match Grid_maps.Grid.find data.tiles tile with
      | Some Grid_maps.Tile_kind.Tall_grass -> "grass"
      | Some _ -> "not grass"
      | None -> "off the map")

let patch map tile pace =
  Printf.sprintf "%s %s %s, %s %s" map
    (Grid_geometry.Tile_pos.to_string tile)
    (kind map tile)
    (Grid_geometry.Tile_pos.to_string (Grid_geometry.Tile_pos.next tile pace))
    (kind map (Grid_geometry.Tile_pos.next tile pace))

let strategy name () =
  let s =
    List.find
      (fun (s : Frlg_actions.Grind_plan.strategy) -> s.name = name)
      (Result.get_ok (Frlg_actions.Grind_plan.load_strategies ()))
  in
  patch s.spot.map (List.hd s.spot.tiles) s.pace

(* The plan's paced events, each from the tile the event before it names. *)
let plan_patches file () =
  let p = Result.get_ok (Frlg_checkpoints.Plan_file.load file) in
  let named (e : Pokemon_checkpoints.Plan.event) =
    match (e.kind, e.declared_after) with
    | Game (Route r), _ -> Some r.target
    | _, Some (Grid g) -> Some g
    | _ -> None
  in
  let paced (before, out) (e : Pokemon_checkpoints.Plan.event) =
    let out =
      match (e.kind, e.way, before) with
      | Named_action args, Some ("capture" | "prepare_berry_pp"), Some g ->
          let pace = Grid_maps.Grid_field.direction ~where:"" "pace" args in
          patch g.Pokemon_checkpoints.Pose.map (List.hd g.tiles) pace :: out
      | _ -> out
    in
    (Option.fold ~none:before ~some:Option.some (named e), out)
  in
  let _, out = List.fold_left paced (None, []) p.checkpoint.events in
  String.concat "; " (List.rev out)

let cases =
  [
    case "the Victory Road 2F grind"
      (strategy "victory_road_2f")
      "VictoryRoad_2F (45, 10) grass, (44, 10) grass";
    case "the Pokemon Tower 5F grind"
      (strategy "pokemon_tower_5f")
      "PokemonTower_5F (8, 9) grass, (9, 9) grass";
    case "02-trade-farfetchd's Spearow capture"
      (plan_patches "02-trade-farfetchd.plan.json")
      "Route16 (35, 6) grass, (36, 6) grass";
    case "07-glitch-prep's Blizzard PP drain"
      (plan_patches "07-glitch-prep.plan.json")
      "Route8 (45, 12) grass, (44, 12) grass";
  ]

let () = Table_test.run "paced_patches" cases
