(* The Mail Glitch plans 01-celadon-setup..08-activate-and-verify against FireRed's story game: each is a
   FireRed plan it runs, from its start tile, and the game actions it names
   that FireRed has no handler for yet (the runner refuses such a plan before
   its first event). *)

open Frlg_checkpoints

let plan file = Result.get_ok (Frlg_checkpoints.Plan_file.load file)

let handled =
  "fly" :: "lift_floor" :: "capture" :: "wild_rng" :: "save_game" :: "grind"
  :: "prepare_berry_pp" :: "mail_glitch_double_battle"
  :: Frlg_actions.Action_requests.names
  @ List.map fst
      (Frlg_actions.Mail_glitch_use.handlers ~log:ignore
         ~party:(ref (Frlg_actions.Party_roster.of_list [])))

let missing (p : Pokemon_engine.Plan.t) =
  List.filter_map
    (fun (e : Pokemon_engine.Plan.event) ->
      match (e.kind, e.way) with
      | Named_action _, Some name when not (List.mem name handled) -> Some name
      | _ -> None)
    p.checkpoint.events
  |> List.sort_uniq compare

let summary file () =
  let p = plan file in
  let checked =
    match Checkpoint_run.check_plan p with Ok () -> "frlg" | Error e -> e
  in
  let start =
    Option.fold ~none:"no start" ~some:Pokemon_engine.Pose.to_string
      p.checkpoint.start
  in
  let missing =
    match missing p with [] -> "none" | l -> String.concat ", " l
  in
  Printf.sprintf "%s; from %s; missing: %s" checked start missing

(* Where the player stands after an event that names it, as the story game
   reckons it: a walk's target, a lift ride's exit, a single declared tile. *)
let reckoned (e : Pokemon_engine.Plan.event) :
    Pokemon_engine.Pose.observed option =
  let of_grid (g : Pokemon_engine.Pose.grid) =
    match g.tiles with
    | [ tile ] ->
        Some
          {
            Pokemon_engine.Pose.at_map = g.map;
            at_tile = tile;
            faces = g.facing;
          }
    | _ -> None
  in
  match (e.kind, e.way) with
  | Game (Route r), _ -> of_grid r.target
  | Named_action args, Some "lift_floor" ->
      Result.to_option (Frlg_actions.Lift_ride.ride_of_args args)
      |> Option.map Frlg_actions.Lift_ride.arrival
  | _ ->
      Option.bind e.declared_after (function Grid g -> of_grid g | _ -> None)

(* Each walk of the plan planned on the maps from where the events before it
   leave the player: its leg count, or why it has none. *)
let walks file () =
  let p = plan file in
  let world = Result.get_ok (Checkpoint_run.load_world ()) in
  let step (at, out) (e : Pokemon_engine.Plan.event) =
    let out =
      match (e.kind, at) with
      | Game (Route r), Some (at : Pokemon_engine.Pose.observed) ->
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

(* check_plan on a plan that starts anywhere outdoors, its first event [first]. *)
let anywhere_first first () =
  let text =
    Printf.sprintf
      {|{"format": "gamepilot-checkpoint/1", "game": "frlg", "execution": {"menu": "full"},
  "checkpoint": {"id": "cp", "title": "Test", "start": {"anywhere": "outdoors"},
    "events": [%s]}}|}
      first
  in
  match
    Pokemon_engine.Plan_decode.decode ~source:"cp.plan.json"
      (Yojson.Safe.from_string text)
  with
  | Error e -> e
  | Ok p -> (
      match Checkpoint_run.check_plan p with Ok () -> "frlg" | Error e -> e)

(* What a run checks and skips with --grind-battles [cap]. *)
let capped cap file () =
  let p = plan file in
  let kept, skipped = Checkpoint_run.capped_postconditions ~grind_cap:cap p in
  Printf.sprintf "knows checked: %d, levels checked: %d; skipped: %s"
    (List.length kept.knows) (List.length kept.levels)
    (match skipped with [] -> "none" | l -> String.concat "; " l)

(* The grind's save point: 04-grind-farfetchd ends at 05-grind-mr-mime's start, and every round
   (05-grind-mr-mime) ends there too, where 06-grind-return starts. *)
let grind_save_point () =
  let start id =
    match (plan (id ^ ".plan.json")).checkpoint.start with
    | Some (Grid g) -> Pokemon_engine.Pose.grid_to_string g
    | Some (Zone _ | Anywhere _) | None -> "not a tile"
  in
  let a = plan "04-grind-farfetchd.plan.json"
  and b = plan "05-grind-mr-mime.plan.json" in
  let ends =
    [
      Checkpoint_end.declared ~next:(Some b.checkpoint) a.checkpoint;
      Option.bind b.postconditions (fun p -> p.position);
    ]
  in
  String.concat "; "
    (List.map
       (Option.fold ~none:"none" ~some:Pokemon_engine.Pose.grid_to_string)
       ends
    @ [ start "05-grind-mr-mime"; start "06-grind-return" ])

(* 03-trade-mr-mime run from its last event (heal_lavender, after buy_revives): the
   checkpoint's start reads as a whole run kept them beside the event's state
   (no Escape Rope at the start), read back from that file, and the end's read
   after the purchase (one rope). [kept_ropes] is the start count kept. *)
let from_last_event ~kept_ropes () =
  let p = plan "03-trade-mr-mime.plan.json" in
  let events =
    List.map (fun (e : Pokemon_engine.Plan.event) -> e.id) p.checkpoint.events
  in
  let range =
    Result.get_ok
      (Engine_run.Event_range.resolve events ~from_event:"heal_lavender"
         ~to_event:None)
  in
  let kept : Pokemon_engine.Saved.t =
    {
      start =
        {
          start_money = Some 29202;
          start_coins = None;
          start_caught = None;
          start_items = [ ("revive", 0); ("escape-rope", kept_ropes) ];
        };
      at = None;
    }
  in
  let kept =
    Result.get_ok
      (Pokemon_engine.Saved.of_yojson (Pokemon_engine.Saved.to_yojson kept))
  in
  let observed =
    {
      Pokemon_engine.Postcondition_check.nothing_read with
      items = [ ("revive", 2); ("escape-rope", 1) ];
      start = kept.start;
    }
  in
  let rope =
    List.find
      (fun (r : Pokemon_engine.Postcondition_check.result) ->
        r.what = "item escape-rope")
      (Pokemon_engine.Postcondition_check.check
         (Option.get p.postconditions)
         observed)
  in
  Printf.sprintf "%s: %s"
    (Engine_run.Event_range.label events range.first)
    (Pokemon_engine.Postcondition_check.result_to_string rope)

let () =
  Table_test.run "checkpoint_run"
    [
      case "01-celadon-setup"
        (summary "01-celadon-setup.plan.json")
        "frlg; from anywhere outdoors; missing: none";
      case "01-celadon-setup's walks plan on the maps"
        (walks "01-celadon-setup.plan.json")
        "to_coin_case_man 8; to_4f_clerk 11; to_4f_clerk.walk 3; \
         to_coins_clerk 3; to_coins_clerk.walk 10; to_prize_clerk 5; \
         exit_prize_room 1";
      case "02-trade-farfetchd"
        (summary "02-trade-farfetchd.plan.json")
        "frlg; from CeladonCity (39, 21) south; missing: none";
      case "02-trade-farfetchd's walks plan on the maps"
        (walks "02-trade-farfetchd.plan.json")
        "to_route16_cut_tree 7; to_route16_grass 4; to_route6_pond_wall 2; \
         to_route6_sitrus_berry 9; to_vermilion_mart_wall 3; \
         to_vermilion_elyssa 5; exit_vermilion_house2 1";
      case "03-trade-mr-mime"
        (summary "03-trade-mr-mime.plan.json")
        "frlg; from VermilionCity (19, 18) south; missing: none";
      case "03-trade-mr-mime's walks plan on the maps"
        (walks "03-trade-mr-mime.plan.json")
        "to_route2_cut_tree 3; to_route2_reyley 8; exit_route2_house 3; \
         to_lavender_mart 7; heal_lavender.walk 8";
      case
        "03-trade-mr-mime from its last event: the rope gained from the kept \
         start"
        (from_last_event ~kept_ropes:0)
        "#11 heal_lavender: item escape-rope: passed: gained 1 (0 to 1)";
      case "re-read at that event (after the purchase), it would read gained 0"
        (from_last_event ~kept_ropes:1)
        "#11 heal_lavender: item escape-rope: failed: expected gained 1, read \
         gained 0 (1 to 1)";
      case "07-glitch-prep"
        (summary "07-glitch-prep.plan.json")
        "frlg; from LavenderTown (18, 7) south; missing: none";
      case "07-glitch-prep's walks plan on the maps"
        (walks "07-glitch-prep.plan.json")
        "lavender_mart_clerk 6; out_of_lavender_mart 1; return_to_tower_door \
         4; to_route8_cut_tree 9; to_route8_grass 1; face_route8_leppa_berry \
         2; return_to_route8_grass 3; to_route16_cut_tree 6; to_lea_and_jed 3";
      case "04-grind-farfetchd"
        (summary "04-grind-farfetchd.plan.json")
        "frlg; from LavenderTown_PokemonCenter_1F (7, 4) north; missing: none";
      case "04-grind-farfetchd's walks plan on the maps"
        (walks "04-grind-farfetchd.plan.json")
        "to_tower_5f_patch 34; heal_indigo.walk 4";
      case "05-grind-mr-mime (the grind round)"
        (summary "05-grind-mr-mime.plan.json")
        "frlg; from IndigoPlateau_PokemonCenter_1F (13, 12) north; missing: \
         none";
      case
        "04-grind-farfetchd's end, a round's end, the round's and \
         06-grind-return's start: the Indigo nurse"
        grind_save_point
        "IndigoPlateau_PokemonCenter_1F (13, 12) north; \
         IndigoPlateau_PokemonCenter_1F (13, 12) north; \
         IndigoPlateau_PokemonCenter_1F (13, 12) north; \
         IndigoPlateau_PokemonCenter_1F (13, 12) north";
      case "06-grind-return"
        (summary "06-grind-return.plan.json")
        "frlg; from IndigoPlateau_PokemonCenter_1F (13, 12) north; missing: \
         none";
      case "06-grind-return's walks plan on the maps"
        (walks "06-grind-return.plan.json")
        "out_to_indigo_plateau 2; to_glitch_prep_start 4";
      case "06-grind-return uncapped: every postcondition checked"
        (capped None "06-grind-return.plan.json")
        "knows checked: 2, levels checked: 1; skipped: none";
      case "06-grind-return capped at 8: the grind's moves skipped, saying so"
        (capped (Some 8) "06-grind-return.plan.json")
        "knows checked: 0, levels checked: 0; skipped: knows farfetchd \
         knock-off (grind capped at 8); knows mr-mime recycle (grind capped at \
         8); level mr-mime at least 33 (grind capped at 8)";
      case "08-activate-and-verify"
        (summary "08-activate-and-verify.plan.json")
        "frlg; from Route16 (30, 7) north; missing: none";
      case "08-activate-and-verify's walks plan on the maps"
        (walks "08-activate-and-verify.plan.json")
        "to_4f_clerk 7; to_4f_clerk.walk 3; to_1f_save_spot 3; \
         out_of_dept_store 3";
      case "a start anywhere outdoors that flies first"
        (anywhere_first
           {|{"id": "fly", "kind": "game_action", "action": "fly", "args": {"town": "CeladonCity", "species": "pidgey"}}|})
        "frlg";
      case "a start anywhere outdoors that walks first: refused"
        (anywhere_first
           {|{"id": "walk", "kind": "route", "action": "run", "args": {"target": {"map": "CeladonCity", "tiles": [[1, 2]]}}}|})
        "a checkpoint that starts anywhere outdoors begins with a fly event";
      case "su-01"
        (summary "su-01.plan.json")
        "frlg; from anywhere outdoors; missing: none";
      case "su-01's walks plan on the maps" (walks "su-01.plan.json")
        "lavender_mart_clerk 7; out_of_lavender_mart 1; to_4f_clerk 7; \
         to_4f_clerk.walk 3; out_of_dept_store 3; out_of_dept_store.walk 3";
      case "tt-01"
        (summary "tt-01.plan.json")
        "frlg; from anywhere outdoors; missing: none";
      case "tt-01's walks plan on the maps" (walks "tt-01.plan.json")
        "face_route6_rare_candy 10; to_save_spot 8; out_of_dept_store 3";
    ]
