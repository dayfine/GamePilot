(* Partial runs from an event (Event_range) and the states kept at each event's
   start (Event_states): the range picked by id or number, the state's path,
   which events of a run get a state, that a partial run never verifies or
   chains and is refused on the Switch, and the money spent checked against the
   checkpoint's start kept with the state. *)

open Engine_run
open Pokemon_checkpoints
open Engine_postcondition

let case name input expectation = { Table_test.name; input; expectation }

let mg02_ids =
  [
    "to_route16_cut_tree";
    "cut_route16_tree";
    "to_route16_grass";
    "catch_spearow";
    "fly_vermilion";
    "to_route6_pond_wall";
    "to_route6_sitrus_berry";
    "pickup_sitrus_berry";
    "clear_berry_text";
    "fly_vermilion_house2";
    "to_vermilion_mart_wall";
    "to_vermilion_elyssa";
    "trade_chding";
    "exit_vermilion_house2";
  ]

let event id = Printf.sprintf {|{"id": "%s", "kind": "scene"}|} id
let mg02 = Plan_files.checkpoint_of_events (List.map event mg02_ids)

let range from_event to_event =
  match Event_range.resolve mg02_ids ~from_event ~to_event with
  | Ok r ->
      let first, last = Event_range.describe r mg02_ids in
      Printf.sprintf "%s .. %s, end checked: %b" first last
        (Event_range.reaches_end r mg02.events)
  | Error e -> "error: " ^ e

let range_cases =
  [
    case "from an id to the end"
      (fun () -> range "trade_chding" None)
      "#13 trade_chding .. #14 exit_vermilion_house2, end checked: true";
    case "from a number, as the log's #13"
      (fun () -> range "13" None)
      "#13 trade_chding .. #14 exit_vermilion_house2, end checked: true";
    case "to an event before the last: no end check"
      (fun () -> range "5" (Some "trade_chding"))
      "#5 fly_vermilion .. #13 trade_chding, end checked: false";
    case "an unknown id"
      (fun () -> range "trade" None)
      "error: no event trade in the checkpoint";
    case "a number past the last"
      (fun () -> range "15" None)
      "error: no event #15 (the checkpoint has 14)";
    case "to before from"
      (fun () -> range "13" (Some "2"))
      "error: --to-event 2 comes before --from-event 13";
  ]

let path_cases =
  [
    case "a state's path: number from 1, two digits, and the event id"
      (fun () ->
        Event_states.path ~states:"/s" ~checkpoint:"mg-02" ~index:12
          ~event_id:"trade_chding")
      (Filename.concat
         (Filename.concat "/s" "mg-02.events")
         "13-trade_chding.ss");
    case "the first event"
      (fun () -> Event_states.file ~index:0 ~event_id:"to_route16_cut_tree")
      "01-to_route16_cut_tree.ss";
    case "what is kept beside it"
      (fun () -> Event_states.kept_path "/s/mg-02.events/13-trade_chding.ss")
      "/s/mg-02.events/13-trade_chding.json";
    case "pruned: the same number under an old id, not the kept one or others"
      (fun () ->
        [
          "13-trade_chding.ss";
          "13-trade_chding.json";
          "13-trade.ss";
          "13-trade.json";
          "12-to_vermilion_elyssa.ss";
          "13-trade.ss.tmp";
        ]
        |> List.filter
             (Event_states.is_other_state ~index:12 ~keep:"13-trade_chding.ss")
        |> String.concat ", ")
      "13-trade.ss, 13-trade.json";
  ]

(* The events whose state a run keeps, as numbers from 1, hearing [heard]. *)
let kept ~first heard =
  let t = Event_states.tracker ~first in
  List.filter_map
    (fun (i, p) -> if Event_states.hear t i p then Some (i + 1) else None)
    heard
  |> List.map string_of_int |> String.concat " "

let started i = (i, Event_progress.Started)
let passed i = (i, Event_progress.Passed)

(* A run of [events] through the runner, the scripted game failing where
   [fails] says; the events whose state it keeps. *)
let run_kept ?events fails =
  let checkpoint =
    Plan_files.checkpoint_of_events (List.map event [ "a"; "b"; "c"; "d" ])
  in
  let game, _ =
    Scripted_game.make
      {
        Scripted_game.script with
        fails = List.map (fun id -> (id, Failure.cause "x" "failed")) fails;
        flags = [ "met" ];
      }
  in
  let first = Option.fold ~none:0 ~some:(fun r -> r.Event_range.first) events in
  let t = Event_states.tracker ~first and kept = ref [] in
  let on_event i p = if Event_states.hear t i p then kept := (i + 1) :: !kept in
  ignore (Runner.run ~on_event ?events game checkpoint);
  List.rev_map string_of_int !kept |> String.concat " "

(* A run of a..d from #2 to #3 with a declared end the player never reaches:
   its log's last lines. *)
let to_event_log () =
  let checkpoint =
    Plan_files.checkpoint_of_events (List.map event [ "a"; "b"; "c"; "d" ])
  in
  let game, log = Scripted_game.make Scripted_game.script in
  let end_at : Pose.declared =
    Grid { map = "Town"; tiles = [ { x = 4; y = 2 } ]; facing = None }
  in
  let result =
    match
      Runner.run ~end_at ~events:{ first = 1; last = Some 2 } game checkpoint
    with
    | Ok () -> "passed"
    | Error f -> Failure.to_string f
  in
  let lines = String.split_on_char '\n' (log ()) in
  String.concat "\n"
    [ List.hd lines; List.nth lines (List.length lines - 1); result ]

let which_cases =
  [
    case "a clean run: every event at its start"
      (fun () -> run_kept [])
      "1 2 3 4";
    case "a run failing at #3: #3 too (reached after a clean #1 and #2), not #4"
      (fun () -> run_kept [ "c" ])
      "1 2 3";
    case "a run from #3: #3 again and #4"
      (fun () -> run_kept ~events:{ first = 2; last = None } [])
      "3 4";
    case "to an event before the last: runs #2..#3, checks no end" to_event_log
      "[Story] cp: start at #2 b, to #3 c, of 4 events\n\
       [Story] cp: stopped after #3 (--to-event): end not checked\n\
       passed";
    case "a skipped event counts as done"
      (fun () ->
        kept ~first:0
          [ started 0; passed 0; (1, Event_progress.Skipped "met"); started 2 ])
      "1 3";
    case "an event after a failure: none (the prefix is not clean)"
      (fun () ->
        kept ~first:0 [ started 0; (0, Event_progress.Failed "x"); started 1 ])
      "1";
    case "an event heard out of order: none"
      (fun () -> kept ~first:0 [ started 0; passed 0; started 2 ])
      "1";
  ]

let trials = Result.get_ok (Checkpoint_trials.policy Testing)
let verifying = Result.get_ok (Checkpoint_trials.policy Verification)

let check ~mode ~keeps_states ~checkpoints () =
  match Event_range.check ~mode ~keeps_states ~checkpoints with
  | Ok () -> "runs"
  | Error e -> e

let partial_cases =
  [
    case "a partial run's mode" (fun () -> Event_range.mode_name) "from-event";
    case "testing on mGBA, one checkpoint: runs"
      (check ~mode:Testing ~keeps_states:true ~checkpoints:1)
      "runs";
    case "verification: refused, a partial run never verifies"
      (check ~mode:Verification ~keeps_states:true ~checkpoints:1)
      "--from-event runs part of a checkpoint, so it never verifies one: use \
       --mode testing";
    case "on the Switch: refused, no save states"
      (check ~mode:Testing ~keeps_states:false ~checkpoints:1)
      "--from-event starts from a save state kept at the event, and the Switch \
       has no save states: run the checkpoint from the game's save, or \
       --from-event on mGBA (run/run_checkpoints_on_mgba.sh)";
    case "over two checkpoints: refused"
      (check ~mode:Testing ~keeps_states:true ~checkpoints:2)
      "--from-event runs one checkpoint: give --to the same as --from";
    case "a partial run never chains, even under a policy that keeps the end"
      (fun () ->
        Printf.sprintf "whole: %b, partial: %b"
          (Event_range.keeps_end None verifying)
          (Event_range.keeps_end (Some { first = 12; last = None }) verifying))
      "whole: true, partial: false";
    case "nor in testing"
      (fun () ->
        string_of_bool
          (Event_range.keeps_end (Some { first = 12; last = None }) trials))
      "false";
    case "no state yet: says which run makes one"
      (fun () ->
        Event_states.missing ~checkpoint:"mg-02" ~label:"#13 trade_chding"
          ~path:"/s/mg-02.events/13-trade_chding.ss")
      "no state for mg-02 #13 trade_chding yet \
       (/s/mg-02.events/13-trade_chding.ss): a run of mg-02 on mGBA that \
       reaches #13 trade_chding keeps one, e.g. run/run_checkpoints_on_mgba.sh \
       ... --from mg-02 --to mg-02 --mode testing";
  ]

(* A checkpoint that spends $4100 ($29202 to $25102, mg-01's purchase), run
   from an event after the purchase: the start money is the one kept with the
   event's state, the checkpoint's. *)
let spent_from ~start =
  let promised : Postconditions.t =
    {
      position = None;
      party = None;
      items = [];
      coins = None;
      caught = None;
      money = Some (Money.Spent 4100);
      flags = [];
      knows = [];
      levels = [];
      marks = None;
    }
  in
  let observed =
    {
      Postcondition_check.nothing_read with
      start = { Postcondition_check.nothing_at_start with start_money = start };
      money = Some 25102;
    }
  in
  Postcondition_check.check promised observed
  |> List.map Postcondition_check.result_to_string
  |> String.concat "\n"

(* What is kept, written and read back. *)
let round_trip kept =
  match Saved.of_yojson (Saved.to_yojson kept) with
  | Error e -> e
  | Ok { start = { start_money; start_coins; start_caught; start_items }; at }
    ->
      let money =
        Option.fold ~none:"no money" ~some:(Printf.sprintf "$%d") start_money
      and coins =
        Option.fold ~none:"" ~some:(Printf.sprintf ", %d coins") start_coins
      and caught =
        Option.fold ~none:"" ~some:(Printf.sprintf ", %d caught") start_caught
      and items =
        String.concat ""
          (List.map (fun (i, n) -> Printf.sprintf ", %s x%d" i n) start_items)
      in
      let pose (p : Pose.observed) =
        Printf.sprintf "%s (%d, %d) %s" p.at_map p.at_tile.x p.at_tile.y
          (Option.fold ~none:"?" ~some:Grid_geometry.Direction.name p.faces)
      in
      money ^ coins ^ caught ^ items ^ ", "
      ^ Option.fold ~none:"nowhere" ~some:pose at

let money start_money =
  { Postcondition_check.nothing_at_start with start_money }

(* mg-02 #14's start: in Vermilion House 2 after the trade. *)
let house2 : Pose.observed =
  {
    at_map = "VermilionCity_House2";
    at_tile = { x = 4; y = 4 };
    faces = Some North;
  }

let kept_cases =
  [
    case "the checkpoint's start money and the reckoned pose, read back"
      (fun () -> round_trip { start = money (Some 29202); at = Some house2 })
      ("$29202, VermilionCity_House2 (4, 4) "
      ^ Grid_geometry.Direction.name North);
    case "no start money (no spent promise), the pose unknown"
      (fun () -> round_trip { start = money None; at = None })
      "no money, nowhere";
    case "a facing the game could not tell"
      (fun () ->
        round_trip
          { start = money None; at = Some { house2 with faces = None } })
      "no money, VermilionCity_House2 (4, 4) ?";
    case "the coins, the caught count and each item at the start, read back"
      (fun () ->
        round_trip
          {
            start =
              {
                start_money = Some 29202;
                start_coins = Some 50;
                start_caught = Some 12;
                start_items = [ ("revive", 0); ("escape-rope", 4) ];
              };
            at = None;
          })
      "$29202, 50 coins, 12 caught, revive x0, escape-rope x4, nowhere";
    case "kept before items were: no coins or items read at the start"
      (fun () ->
        match
          Saved.of_yojson
            (`Assoc [ ("start_money", `Int 29202); ("at", `Null) ])
        with
        | Ok { start; _ } -> string_of_bool (start = money (Some 29202))
        | Error e -> e)
      "true";
    case "an item count that is not a number"
      (fun () ->
        match
          Saved.of_yojson
            (`Assoc [ ("start_items", `Assoc [ ("revive", `String "2") ]) ])
        with
        | Ok _ -> "read"
        | Error e -> e)
      "start_items: revive is not a number";
    case "not an object"
      (fun () ->
        match Saved.of_yojson (`Int 1) with Ok _ -> "read" | Error e -> e)
      "what is kept is not an object";
    case "a kept pose with no map: the derived reader names the field"
      (fun () ->
        let pose = [ ("tile", `List [ `Int 4; `Int 4 ]); ("facing", `Null) ] in
        match Saved.of_yojson (`Assoc [ ("at", `Assoc pose) ]) with
        | Ok _ -> "read"
        | Error e -> e)
      "Pokemon_saved.observed.at_map";
    case "spent, checked from the event against the checkpoint's start"
      (fun () -> spent_from ~start:(Some 29202))
      "money: passed: spent $4100 ($29202 to $25102)";
    case "re-read at the event (after the purchase), it would read $0 spent"
      (fun () -> spent_from ~start:(Some 25102))
      "money: failed: expected spent $4100, read spent $0 ($25102 to $25102)";
  ]

let () =
  Table_test.run "event states"
    (range_cases @ path_cases @ which_cases @ partial_cases @ kept_cases)
