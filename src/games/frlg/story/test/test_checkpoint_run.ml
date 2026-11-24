(* The Mail Glitch plans mg-01..mg-06 against FireRed's story game: each is a
   FireRed plan it runs, from its start tile, and the game actions it names
   that FireRed has no handler for yet (the runner refuses such a plan before
   its first event). *)

open Frlg_story

let plan file = Result.get_ok (Story.Plan_decode.load file)

let handled =
  "fly" :: "lift_floor" :: "capture" :: "grind" :: "prepare_berry_pp"
  :: "mail_glitch_double_battle" :: Frlg_actions.Action_requests.names
  @ List.map fst
      (Frlg_actions.Mail_glitch_use.handlers ~log:ignore
         ~party:(ref (Frlg_actions.Party_roster.of_list [])))

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

let case name input expectation = { Table_test.name; input; expectation }

(* What a run checks and skips with --grind-battles [cap]. *)
let capped cap file () =
  let p = plan file in
  let kept, skipped = Checkpoint_run.capped_postconditions ~grind_cap:cap p in
  Printf.sprintf "knows checked: %d, levels checked: %d; skipped: %s"
    (List.length kept.knows) (List.length kept.levels)
    (match skipped with [] -> "none" | l -> String.concat "; " l)

(* The grind's save point: mg-04a ends at mg-04b's start, and every round
   (mg-04b) ends there too, where mg-04c starts. *)
let grind_save_point () =
  let start id =
    match (plan (id ^ ".plan.json")).checkpoint.start with
    | Some (Grid g) -> Story.Pose.grid_to_string g
    | Some (Zone _) | None -> "not a tile"
  in
  let a = plan "mg-04a.plan.json" and b = plan "mg-04b.plan.json" in
  let ends =
    [
      Story.Checkpoint_end.declared ~next:(Some b.checkpoint) a.checkpoint;
      b.postconditions.position;
    ]
  in
  String.concat "; "
    (List.map (Option.fold ~none:"none" ~some:Story.Pose.grid_to_string) ends
    @ [ start "mg-04b"; start "mg-04c" ])

(* mg-03 run from its last event (heal_lavender, after buy_revives): the
   checkpoint's start reads as a whole run kept them beside the event's state
   (no Escape Rope at the start), read back from that file, and the end's read
   after the purchase (one rope). [kept_ropes] is the start count kept. *)
let from_last_event ~kept_ropes () =
  let p = plan "mg-03.plan.json" in
  let events = p.checkpoint.events in
  let range =
    Result.get_ok
      (Story.Event_range.resolve events ~from_event:"heal_lavender"
         ~to_event:None)
  in
  let kept : Story.Event_states.kept =
    {
      start =
        {
          start_money = Some 29202;
          start_coins = None;
          start_items = [ ("revive", 0); ("escape-rope", kept_ropes) ];
        };
      at = None;
    }
  in
  let kept =
    Result.get_ok
      (Story.Event_states.kept_of_json (Story.Event_states.kept_to_json kept))
  in
  let observed =
    {
      Story.Postcondition_check.nothing_read with
      items = [ ("revive", 2); ("escape-rope", 1) ];
      start = kept.start;
    }
  in
  let rope =
    List.find
      (fun (r : Story.Postcondition_check.result) ->
        r.what = "item escape-rope")
      (Story.Postcondition_check.check p.postconditions observed)
  in
  Printf.sprintf "%s: %s"
    (Story.Event_range.label events range.first)
    (Story.Postcondition_check.result_to_string rope)

let () =
  Table_test.run "checkpoint_run"
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
      case "mg-03 from its last event: the rope gained from the kept start"
        (from_last_event ~kept_ropes:0)
        "#11 heal_lavender: item escape-rope: passed: gained 1 (0 to 1)";
      case "re-read at that event (after the purchase), it would read gained 0"
        (from_last_event ~kept_ropes:1)
        "#11 heal_lavender: item escape-rope: failed: expected gained 1, read \
         gained 0 (1 to 1)";
      case "mg-05a"
        (summary "mg-05a.plan.json")
        "frlg; from LavenderTown (18, 7) south; missing: none";
      case "mg-05a's walks plan on the maps" (walks "mg-05a.plan.json")
        "lavender_mart_clerk 6; out_of_lavender_mart 1; return_to_tower_door \
         4; to_route8_cut_tree 9; to_route8_grass 1; face_route8_leppa_berry \
         2; return_to_route8_grass 3; to_route16_cut_tree 6; to_lea_and_jed 3";
      case "mg-04a"
        (summary "mg-04a.plan.json")
        "frlg; from LavenderTown_PokemonCenter_1F (7, 4) north; missing: none";
      case "mg-04a's walks plan on the maps" (walks "mg-04a.plan.json")
        "to_tower_5f_patch 34; to_indigo_nurse 4";
      case "mg-04b (the grind round)"
        (summary "mg-04b.plan.json")
        "frlg; from IndigoPlateau_PokemonCenter_1F (13, 12) north; missing: \
         none";
      case
        "mg-04a's end, a round's end, the round's and mg-04c's start: the \
         Indigo nurse"
        grind_save_point
        "IndigoPlateau_PokemonCenter_1F (13, 12) north; \
         IndigoPlateau_PokemonCenter_1F (13, 12) north; \
         IndigoPlateau_PokemonCenter_1F (13, 12) north; \
         IndigoPlateau_PokemonCenter_1F (13, 12) north";
      case "mg-04c"
        (summary "mg-04c.plan.json")
        "frlg; from IndigoPlateau_PokemonCenter_1F (13, 12) north; missing: \
         none";
      case "mg-04c's walks plan on the maps" (walks "mg-04c.plan.json")
        "out_to_indigo_plateau 2; to_mg05_start 4";
      case "mg-04c uncapped: every postcondition checked"
        (capped None "mg-04c.plan.json")
        "knows checked: 2, levels checked: 1; skipped: none";
      case "mg-04c capped at 8: the grind's moves skipped, saying so"
        (capped (Some 8) "mg-04c.plan.json")
        "knows checked: 0, levels checked: 0; skipped: knows farfetchd \
         knock-off (grind capped at 8); knows mr-mime recycle (grind capped at \
         8); level mr-mime at least 33 (grind capped at 8)";
      case "mg-05"
        (summary "mg-05.plan.json")
        "frlg; from Route16 (30, 7) north; missing: none";
      case "mg-06"
        (summary "mg-06.plan.json")
        "frlg; from Route16 (30, 6) north; missing: none";
      case "mg-06's walks plan on the maps" (walks "mg-06.plan.json")
        "to_dept_store_lift 7; to_4f_clerk 3; back_to_4f_lift 3";
    ]
