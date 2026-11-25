(* FireRed's Game.t through the story runner: a route out of the player's
   house, then a talk, on a scripted screen; a route with no position to walk
   from; and the plan's one-tile step. *)

open Frlg_actions
open Frlg_overworld_fixtures
module S = Scripted_screen

let event id kind : Pokemon_engine.Plan.event =
  {
    id;
    kind;
    way = None;
    why = id;
    skip_if = [];
    declared_after = None;
    once_per_save = false;
  }

let pallet_door : Pokemon_engine.Pose.grid =
  { map = "PalletTown"; tiles = [ { x = 6; y = 8 } ]; facing = None }

let checkpoint : Pokemon_engine.Plan.checkpoint =
  {
    checkpoint_id = "test";
    title = "out and talk";
    start = None;
    events =
      [
        event "out"
          (Game
             (Route
                {
                  target = pallet_door;
                  fight_wild = false;
                  fight_trainers = false;
                }));
        event "talk" Talk;
      ];
  }

(* A hold's warp fades; an A shows text for a second. *)
let react screen (p : S.press) =
  if S.holds_dpad p && p.hold_ms > 160 then (
    S.show screen ~at_ms:(p.at_ms + p.hold_ms + 50) S.Black;
    S.show screen ~at_ms:(p.at_ms + p.hold_ms + 450) S.Overworld);
  if p.buttons = [ Wire.A ] then (
    S.show screen ~at_ms:(p.at_ms + 200) S.Dialog;
    S.show screen ~at_ms:(p.at_ms + 1200) S.Overworld)

let run ?(world = Frlg_world.pallet) ?(react = react) ?(checkpoint = checkpoint)
    ?(party = []) start () =
  let screen = S.create ~react () in
  let config : Checkpoint_game.config =
    {
      world;
      gait = Walking;
      flee = ignore;
      flags = (fun _ -> false);
      party = Some (Party_roster.of_list party);
      grind_cap = None;
      center = None;
      reload = (fun () -> Ok ());
      log = ignore;
    }
  in
  let t = Checkpoint_game.create config ~start in
  let result =
    S.run screen (fun () ->
        Pokemon_engine.Runner.run (Checkpoint_game.game t) checkpoint)
  in
  let outcome =
    match result with
    | Ok () -> "ok"
    | Error f -> Pokemon_engine.Failure.to_string f
  in
  let at =
    Option.fold ~none:"unknown" ~some:Pokemon_engine.Pose_text.observed
      ((Checkpoint_game.game t).position ())
  in
  Printf.sprintf "%s; at %s; %s" outcome at (S.presses_text screen)

let house : Pokemon_engine.Pose.observed =
  {
    at_map = "PalletTown_PlayersHouse_1F";
    at_tile = { x = 4; y = 6 };
    faces = None;
  }

let swap_event species : Pokemon_engine.Plan.event =
  {
    (event "swap"
       (Named_action [ ("species", `String species); ("target_slot", `Int 1) ]))
    with
    way = Some "party_swap";
  }

let swap_checkpoint species =
  { checkpoint with events = [ swap_event species ] }

(* A trade that ran before this save passes without a press; its declared
   tile is where the player is taken to stand, as for a built-in event. *)
let done_trade : Pokemon_engine.Plan.event =
  {
    (event "trade"
       (Named_action
          [ ("species", `String "spearow"); ("receive", `String "farfetchd") ]))
    with
    way = Some "ingame_trade";
    declared_after =
      Some
        (Grid
           {
             map = "PalletTown_PlayersHouse_1F";
             tiles = [ { x = 3; y = 5 } ];
             facing = Some North;
           });
  }

(* The trade declared on the tile the player stands on, with no facing: the
   facing reckoned before it stays (mg-04 testing run 9: Fly's landing facing
   south was lost to its declared tile, and the walk after it led with a turn
   tap). *)
let done_trade_no_facing : Pokemon_engine.Plan.event =
  {
    done_trade with
    declared_after =
      Some
        (Grid
           {
             map = "PalletTown_PlayersHouse_1F";
             tiles = [ { x = 4; y = 6 } ];
             facing = None;
           });
  }

(* mg-02's Cut, then its walk north through the tree's tile to the grass. *)
let cut_then_grass : Pokemon_engine.Plan.checkpoint =
  {
    checkpoint_id = "test";
    title = "cut and on";
    start = None;
    events =
      [
        {
          (event "cut" (Named_action [ ("direction", `String "north") ])) with
          way = Some "cut_tree";
        };
        event "grass"
          (Game
             (Route
                {
                  target =
                    {
                      map = "Route16";
                      tiles = [ { x = 35; y = 6 } ];
                      facing = Some East;
                    };
                  fight_wild = false;
                  fight_trainers = false;
                }));
      ];
  }

(* A on the tree asks; YES fells it. *)
let cut_screen screen (p : S.press) =
  let show d s = S.show screen ~at_ms:(p.at_ms + d) s in
  if p.buttons = [ Wire.A ] then
    match S.screen_at screen p.at_ms with
    | S.Overworld -> show 200 S.Question
    | S.Question ->
        show 100 S.Dialog;
        show 1600 S.Overworld
    | _ -> ()

let below_tree : Pokemon_engine.Pose.observed =
  { at_map = "Route16"; at_tile = { x = 41; y = 12 }; faces = Some North }

(* The plan's [step]: one tile, nothing watched, as onto a scene's tile. *)
let step_checkpoint direction =
  { checkpoint with events = [ event "step" (Game (Step direction)) ] }

let in_pallet faces : Pokemon_engine.Pose.observed =
  { at_map = "PalletTown"; at_tile = { x = 12; y = 9 }; faces }

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "checkpoint_game"
    [
      case "a step: one tile on, facing its way"
        (run ~checkpoint:(step_checkpoint West) (Some (in_pallet (Some West))))
        "ok; at PalletTown (11, 9) west; left 267";
      case "a step facing another way: a turn tap first"
        (run ~checkpoint:(step_checkpoint West) (Some (in_pallet (Some South))))
        "ok; at PalletTown (11, 9) west; left, left 267";
      case
        "a step off the exit mat, through its warp, is refused, nothing pressed"
        (run ~checkpoint:(step_checkpoint South)
           (Some { house with at_tile = { x = 4; y = 8 }; faces = Some South }))
        "test event 1 (step): step_unsupported: the step south takes a warp or \
         may meet a wild battle; at PalletTown_PlayersHouse_1F (4, 8) south; ";
      case "a step with no position to step from"
        (run ~checkpoint:(step_checkpoint West) None)
        "test event 1 (step): position_unknown: no position to walk from; at \
         unknown; ";
      case "a route out of the house, then a talk" (run (Some house))
        "ok; at PalletTown (6, 8) south; down, down 667, A, B x6";
      case "no position to walk from" (run None)
        "test event 1 (out): position_unknown: no position to walk from; at \
         unknown; ";
      case "a party swap of a species the party lacks presses nothing"
        (run ~checkpoint:(swap_checkpoint "mr-mime") (Some house))
        "test event 1 (swap): not_in_party: mr-mime is not in the party (); at \
         PalletTown_PlayersHouse_1F (4, 6); ";
      case "a game action that passed leaves the player on its declared tile"
        (run
           ~checkpoint:{ checkpoint with events = [ done_trade ] }
           ~party:[ "farfetchd" ] (Some house))
        "ok; at PalletTown_PlayersHouse_1F (3, 5) north; ";
      case
        "a declared tile with no facing, where the player stands, keeps the \
         facing"
        (run
           ~checkpoint:{ checkpoint with events = [ done_trade_no_facing ] }
           ~party:[ "farfetchd" ]
           (Some { house with faces = Some South }))
        "ok; at PalletTown_PlayersHouse_1F (4, 6) south; ";
      case
        "after a Cut the player stands on the tree's tile, and the walk on \
         goes through it"
        (run
           ~world:
             (Frlg_world.world ~edge_stalls:false [ "CeladonCity"; "Route16" ])
           ~react:cut_screen ~checkpoint:cut_then_grass (Some below_tree))
        "ok; at Route16 (35, 6) east; up, A x2, B x6, up, up 667, left, left \
         1468, up, up 400, right";
    ]
