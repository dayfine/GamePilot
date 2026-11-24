(* The Mail Glitch plans mg-01..mg-05 against FireRed's story game: each is a
   FireRed plan it runs, from its start tile, and the game actions it names
   that FireRed has no handler for yet (the runner refuses such a plan before
   its first event). *)

open Frlg_story

let plan file = Result.get_ok (Story.Plan_decode.load file)

let handled =
  "fly" :: "lift_floor" :: "capture" :: "grind" :: "prepare_berry_pp"
  :: "mail_glitch_double_battle" :: Frlg_actions.Action_requests.names

let missing (p : Story.Plan.t) =
  List.filter_map
    (fun (e : Story.Plan.event) ->
      match (e.kind, e.action) with
      | Game_action _, Some name when not (List.mem name handled) -> Some name
      | _ -> None)
    p.checkpoint.events
  |> List.sort_uniq compare

let summary file () =
  let p = plan file in
  let checked =
    match Checkpoint_run.check_plan p with Ok () -> "frlg" | Error e -> e
  in
  let start =
    Option.fold ~none:"no start" ~some:Story.Pose.observed_to_string
      (Checkpoint_run.start_of p.checkpoint)
  in
  let missing =
    match missing p with [] -> "none" | l -> String.concat ", " l
  in
  Printf.sprintf "%s; from %s; missing: %s" checked start missing

(* Where the player stands after an event that names it, as the story game
   reckons it: a walk's target, a lift ride's exit, a single declared tile. *)
let reckoned (e : Story.Plan.event) : Story.Pose.observed option =
  let of_grid (g : Story.Pose.grid) =
    match g.tiles with
    | [ tile ] ->
        Some { Story.Pose.at_map = g.map; at_tile = tile; faces = g.facing }
    | _ -> None
  in
  match (e.kind, e.action) with
  | Route r, _ -> of_grid r.target
  | Game_action args, Some "lift_floor" ->
      Result.to_option (Frlg_actions.Lift_ride.ride_of_args args)
      |> Option.map Frlg_actions.Lift_ride.arrival
  | _ ->
      Option.bind e.declared_after (function Grid g -> of_grid g | _ -> None)

(* Each walk of the plan planned on the maps from where the events before it
   leave the player: its leg count, or why it has none. *)
let walks file () =
  let p = plan file in
  let world = Result.get_ok (Checkpoint_run.load_world ()) in
  let step (at, out) (e : Story.Plan.event) =
    let out =
      match (e.kind, at) with
      | Route r, Some (at : Story.Pose.observed) ->
          let legs =
            Result.bind (Frlg_overworld.Route_target.place_of world at)
              (fun from ->
                Frlg_overworld.Route_target.plan world ~from ~facing:at.faces
                  r.target)
          in
          (e.id ^ " "
          ^
          match legs with Ok l -> string_of_int (List.length l) | Error e -> e)
          :: out
      | _ -> out
    in
    ((match reckoned e with Some _ as r -> r | None -> at), out)
  in
  let _, out =
    List.fold_left step
      (Checkpoint_run.start_of p.checkpoint, [])
      p.checkpoint.events
  in
  String.concat "; " (List.rev out)

let case name input expectation = { Case_table.name; input; expectation }

(* What a run checks and skips with --grind-battles [cap]. *)
let capped cap file () =
  let p = plan file in
  let kept, skipped = Checkpoint_run.capped_postconditions ~grind_cap:cap p in
  Printf.sprintf "knows checked: %d; skipped: %s" (List.length kept.knows)
    (match skipped with [] -> "none" | l -> String.concat "; " l)

let () =
  Case_table.run "checkpoint_run"
    [
      case "mg-01"
        (summary "mg-01.plan.json")
        "frlg; from CeladonCity (48, 12) south; missing: none";
      case "mg-01's walks plan on the maps" (walks "mg-01.plan.json")
        "to_coin_case_man 8; to_dept_store_lift 11; to_4f_clerk 3; \
         back_to_4f_lift 3; to_coins_clerk 10; to_prize_clerk 5; \
         exit_prize_room 1";
      case "mg-02"
        (summary "mg-02.plan.json")
        "frlg; from CeladonCity (39, 21) south; missing: none";
      case "mg-02's walks plan on the maps" (walks "mg-02.plan.json")
        "to_route16_cut_tree 7; to_route16_grass 4; to_route6_pond_wall 2; \
         to_route6_sitrus_berry 9; to_vermilion_mart_wall 3; \
         to_vermilion_elyssa 5; exit_vermilion_house2 1";
      case "mg-03"
        (summary "mg-03.plan.json")
        "frlg; from VermilionCity (19, 18) south; missing: none";
      case "mg-03's walks plan on the maps" (walks "mg-03.plan.json")
        "to_route2_cut_tree 3; to_route2_reyley 8; exit_route2_house 3; \
         to_lavender_mart 7; to_lavender_nurse 8";
      case "mg-05a"
        (summary "mg-05a.plan.json")
        "frlg; from LavenderTown (18, 7) south; missing: none";
      case "mg-05a's walks plan on the maps" (walks "mg-05a.plan.json")
        "lavender_mart_clerk 6; out_of_lavender_mart 1; return_to_tower_door \
         4; to_route8_cut_tree 9; to_route8_grass 1; face_route8_leppa_berry \
         2; return_to_route8_grass 3; to_route16_cut_tree 6; to_lea_and_jed 3";
      case "mg-04"
        (summary "mg-04.plan.json")
        "frlg; from LavenderTown_PokemonCenter_1F (7, 4) north; missing: none";
      case "mg-04's walks plan on the maps" (walks "mg-04.plan.json")
        "to_tower_5f_patch 34; out_of_victory_road 2; to_mg05_start 4";
      case "mg-04 uncapped: every postcondition checked"
        (capped None "mg-04.plan.json")
        "knows checked: 2; skipped: none";
      case "mg-04 capped at 8: the grind's moves skipped, saying so"
        (capped (Some 8) "mg-04.plan.json")
        "knows checked: 0; skipped: knows farfetchd knock-off (grind capped at \
         8); knows mr-mime recycle (grind capped at 8)";
      case "mg-05"
        (summary "mg-05.plan.json")
        "frlg; from Route16 (30, 7) north; missing: none";
    ]
