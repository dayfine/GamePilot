(* Typed verification of frlg.catcher_prep's checkpoint plans against
   PokemonSimulation's maps: expansion, plan validation, route planning from
   Route 4 into Mt. Moon B1F and back to Route 4's Center, and cave encounter
   tiles for the Paras pacing patch. *)

open Frlg_checkpoints
module Pose = Pokemon_engine.Pose
module Plan = Pokemon_engine.Plan
module Route_target = Frlg_overworld.Route_target

let fail fmt =
  Printf.ksprintf
    (fun msg ->
      Printf.eprintf "FAIL %s\n%!" msg;
      exit 1)
    fmt

let check_eq name ~show ~expected ~actual =
  if expected <> actual then
    fail "%s: expected %s, got %s" name (show expected) (show actual)

let load_and_check file =
  match Plan_file.load file with
  | Error e -> fail "load %s: %s" file e
  | Ok plan -> (
      match Checkpoint_run.check_plan plan with
      | Ok () -> plan
      | Error e -> fail "check_plan %s: %s" file e)

let world = lazy (Result.get_ok (Checkpoint_run.load_world ()))

let tile_kind map tile =
  let maps = (Lazy.force world).Frlg_overworld.Frlg_steps.maps in
  match Grid_maps.Connected_maps.find maps map with
  | None -> fail "map %s not found" map
  | Some i ->
      let data = Grid_maps.Connected_maps.map maps i in
      Grid_maps.Grid.find data.tiles tile

let check_route name ~from ~(target : Pose.grid) =
  let w = Lazy.force world in
  match Route_target.place_of w from with
  | Error e -> fail "%s start pose: %s" name e
  | Ok from_place -> (
      match Route_target.plan w ~from:from_place ~facing:from.faces target with
      | Ok _ -> ()
      | Error e -> fail "%s route: %s" name e)

let step_routes plan =
  let rec go pos = function
    | [] -> ()
    | (e : Plan.event) :: rest -> (
        match (e.kind, e.declared_after) with
        | Game (Route { target; _ }), _ ->
            (match pos with
            | Some from -> check_route e.id ~from ~target
            | None -> fail "%s: route with no prior pose" e.id);
            let next : Pose.observed =
              {
                at_map = target.map;
                at_tile = List.hd target.tiles;
                faces = target.facing;
              }
            in
            go (Some next) rest
        | _, Some (Pose.Grid g) ->
            let next : Pose.observed =
              { at_map = g.map; at_tile = List.hd g.tiles; faces = g.facing }
            in
            go (Some next) rest
        | _ -> go pos rest)
  in
  let start =
    match plan.Plan.checkpoint.start with
    | Some (Pose.Grid g) ->
        Some
          ({ at_map = g.map; at_tile = List.hd g.tiles; faces = g.facing }
            : Pose.observed)
    | _ -> None
  in
  go start plan.checkpoint.events

let test_catch_paras () =
  let plan = load_and_check "01-catch-paras.plan.json" in
  check_eq "01 id" ~show:Fun.id ~expected:"01-catch-paras"
    ~actual:plan.checkpoint.checkpoint_id;
  check_eq "01 starts outdoors"
    ~show:(Option.fold ~none:"none" ~some:Pose.to_string)
    ~expected:(Some (Pose.Anywhere Outdoors)) ~actual:plan.checkpoint.start;
  step_routes plan;
  let spot : Grid_geometry.Tile_pos.t = { x = 42; y = 22 } in
  let east = Grid_geometry.Tile_pos.next spot Grid_geometry.Direction.East in
  let show_tile = function
    | Some Grid_maps.Tile_kind.Tall_grass -> "Tall_grass"
    | Some _ -> "other"
    | None -> "None"
  in
  check_eq "MtMoon_B1F (42, 22) is encounter floor" ~show:show_tile
    ~expected:(Some Grid_maps.Tile_kind.Tall_grass)
    ~actual:(tile_kind "MtMoon_B1F" spot);
  check_eq "MtMoon_B1F (43, 22) is encounter floor" ~show:show_tile
    ~expected:(Some Grid_maps.Tile_kind.Tall_grass)
    ~actual:(tile_kind "MtMoon_B1F" east)

let candy_goal (plan : Plan.t) id =
  match
    List.find_opt (fun (e : Plan.event) -> e.id = id) plan.checkpoint.events
  with
  | Some { kind = Named_action args; way = Some "candy_level"; _ } -> (
      match Frlg_actions.Candy_plan.decode_goal args with
      | Ok g -> g
      | Error cause ->
          fail "%s decode_goal: %s" id
            (Pokemon_engine.Failure.cause_to_string cause))
  | _ -> fail "%s: expected candy_level event" id

let test_train_catchers () =
  let plan = load_and_check "02-train-catchers.plan.json" in
  check_eq "02 id" ~show:Fun.id ~expected:"02-train-catchers"
    ~actual:plan.checkpoint.checkpoint_id;
  let paras = candy_goal plan "level_paras_spore" in
  check_eq "paras target_level" ~show:string_of_int ~expected:27
    ~actual:paras.target_level;
  check_eq "paras evolves" ~show:string_of_bool ~expected:true
    ~actual:paras.use.policy.evolve;
  check_eq "paras expect_species"
    ~show:(Option.value ~default:"none")
    ~expected:(Some "parasect") ~actual:paras.species;
  check_eq "paras expect_moves" ~show:(String.concat ",") ~expected:[ "spore" ]
    ~actual:paras.moves;
  let farfetchd = candy_goal plan "level_farfetchd_false_swipe" in
  check_eq "farfetchd target_level" ~show:string_of_int ~expected:46
    ~actual:farfetchd.target_level;
  check_eq "farfetchd does not evolve" ~show:string_of_bool ~expected:false
    ~actual:farfetchd.use.policy.evolve;
  check_eq "farfetchd expect_species"
    ~show:(Option.value ~default:"none")
    ~expected:(Some "farfetchd") ~actual:farfetchd.species;
  check_eq "farfetchd expect_moves" ~show:(String.concat ",")
    ~expected:[ "false-swipe" ] ~actual:farfetchd.moves

let () =
  test_catch_paras ();
  test_train_catchers ();
  print_endline "catcher_prep_plans: 2/2 passed"
