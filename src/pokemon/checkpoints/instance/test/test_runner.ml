(* Runner.run takes a checkpoint's events in order through the game's handlers
   and stops at the first failure, naming the event. *)

open Pokemon_checkpoints
open Engine_promise

let tile x y : Grid_maps.Tile_pos.t = { x; y }

let events =
  [
    {|{"id": "to_door", "kind": "route", "args": {"target": {"map": "Town", "tiles": [[4, 0]]}}, "why": "walk to the door",
       "declared_after": {"map": "Town", "tiles": [[4, 0]], "facing": "north"}}|};
    {|{"id": "buy", "kind": "game_action", "action": "mart", "args": {"budget": 300}}|};
    {|{"id": "chat", "kind": "talk", "skip_if": ["met_clerk"]}|};
    {|{"id": "leave", "kind": "scene", "why": "back to the overworld"}|};
  ]

let checkpoint = Plan_files.checkpoint_of_events events

let run script =
  let game, log = Scripted_game.make script in
  let result =
    match Runner.run game checkpoint with
    | Ok () -> "passed"
    | Error failure -> "stopped: " ^ Failure.to_string failure
  in
  log () ^ "\n" ^ result

let last_line text = text |> String.split_on_char '\n' |> List.rev |> List.hd

(* A run with a declared end; the log's last three lines. *)
let run_to_end script =
  let game, log = Scripted_game.make script in
  let end_at : Pose.declared =
    Grid { map = "Town"; tiles = [ tile 4 2 ]; facing = None }
  in
  let result =
    match Runner.run ~end_at game checkpoint with
    | Ok () -> "passed"
    | Error failure -> "stopped: " ^ Failure.to_string failure
  in
  let lines = String.split_on_char '\n' (log ()) in
  let tail = List.filteri (fun i _ -> i >= List.length lines - 2) lines in
  String.concat "\n" (tail @ [ result ])

let mart = { Scripted_game.script with actions = [ "mart" ] }

let at_door facing : Pose.observed =
  { at_map = "Town"; at_tile = tile 4 0; faces = facing }

let cases : Table_test.case list =
  [
    {
      name = "every event in order, each logged with its why";
      input = (fun () -> run mart);
      expectation =
        {|[Story] cp: start, 4 events
[Story] cp #1 to_door: start (walk to the door)
walk to_door
[Story] cp #1 to_door: done
[Story] cp #2 buy: start
action mart buy
[Story] cp #2 buy: done
[Story] cp #3 chat: start
builtin chat
[Story] cp #3 chat: done
[Story] cp #4 leave: start (back to the overworld)
builtin leave
[Story] cp #4 leave: done
[Story] cp: done
passed|};
    };
    {
      name = "a failing handler stops the run; later events do not run";
      input =
        (fun () ->
          run
            {
              mart with
              fails =
                [ ("buy", Failure.cause "no_money" "300 needed, 120 held") ];
            });
      expectation =
        {|[Story] cp: start, 4 events
[Story] cp #1 to_door: start (walk to the door)
walk to_door
[Story] cp #1 to_door: done
[Story] cp #2 buy: start
action mart buy
[Story] cp #2 buy: failed: no_money: 300 needed, 120 held
stopped: cp event 2 (buy): no_money: 300 needed, 120 held|};
    };
    {
      name = "a game action the game lacks fails before any event runs";
      input = (fun () -> run Scripted_game.script);
      expectation =
        {|[Story] cp: not started: cp event 2 (buy): no handler for game action "mart"
stopped: cp event 2 (buy): no handler for game action "mart"|};
    };
    {
      name = "a flag in skip_if skips the event";
      input = (fun () -> run { mart with flags = [ "met_clerk" ] });
      expectation =
        {|[Story] cp: start, 4 events
[Story] cp #1 to_door: start (walk to the door)
walk to_door
[Story] cp #1 to_door: done
[Story] cp #2 buy: start
action mart buy
[Story] cp #2 buy: done
[Story] cp #3 chat: skipped (met_clerk)
[Story] cp #4 leave: start (back to the overworld)
builtin leave
[Story] cp #4 leave: done
[Story] cp: done
passed|};
    };
    {
      name = "read away from declared_after: stops at that event";
      input =
        (fun () ->
          run
            {
              mart with
              read_after =
                [
                  ("to_door", { (at_door (Some North)) with at_tile = tile 4 1 });
                ];
            }
          |> String.split_on_char '\n' |> List.rev |> List.hd);
      expectation =
        "stopped: cp event 1 (to_door): declared after at Town (4, 0) north, \
         but the game reads Town (4, 1) north";
    };
    {
      name = "read facing elsewhere: stops";
      input =
        (fun () ->
          run { mart with read_after = [ ("to_door", at_door (Some South)) ] }
          |> String.split_on_char '\n' |> List.rev |> List.hd);
      expectation =
        "stopped: cp event 1 (to_door): declared after at Town (4, 0) north, \
         but the game reads Town (4, 0) south";
    };
    {
      name = "facing the game cannot read is not checked";
      input =
        (fun () ->
          run { mart with read_after = [ ("to_door", at_door None) ] }
          |> String.split_on_char '\n' |> List.rev |> List.hd);
      expectation = "passed";
    };
    {
      name = "the player at the declared end: holds";
      input =
        (fun () ->
          run_to_end
            {
              mart with
              read_after =
                [ ("leave", { (at_door None) with at_tile = tile 4 2 }) ];
            });
      expectation =
        "[Story] cp end Town (4, 2): holds\n[Story] cp: done\npassed";
    };
    {
      name = "the player elsewhere at the end: stops at the end";
      input =
        (fun () ->
          run_to_end { mart with read_after = [ ("leave", at_door None) ] });
      expectation =
        "[Story] cp #4 leave: done\n\
         [Story] cp end Town (4, 2): failed: declared end at Town (4, 2), but \
         the game reads Town (4, 0)\n\
         stopped: cp event 5 (end): declared end at Town (4, 2), but the game \
         reads Town (4, 0)";
    };
    {
      name = "a game that cannot tell where the player ends: stops";
      input = (fun () -> run_to_end mart |> last_line);
      expectation =
        "stopped: cp event 5 (end): declared end at Town (4, 2), but the game \
         reads no position";
    };
  ]

(* A run whose plan promises Abra in the party and 20 coins, the game reading
   [observed] (and logging that it read); the log after the last event. *)
let promised : Postconditions.t =
  {
    position = None;
    party = Some (Party_includes { members = [ "abra" ]; slots = [] });
    items = [];
    coins = Some (Count.Exactly 20);
    money = None;
    flags = [];
    knows = [];
    levels = [];
    marks = None;
  }

let run_with_end_state ?end_at ?(promised = promised) observed =
  let game, log = Scripted_game.make mart in
  let observe _ =
    game.log "read the end state";
    observed
  in
  (* As FireRed's run: only promises read at the end are checked there. *)
  let end_state =
    Option.map (fun p -> (p, observe)) (Postconditions.at_end promised)
  in
  let result =
    match Runner.run ?end_at ?end_state game checkpoint with
    | Ok () -> "passed"
    | Error failure -> "stopped: " ^ Failure.to_string failure
  in
  let lines = String.split_on_char '\n' (log ()) in
  let after_events =
    List.filteri
      (fun i _ ->
        i
        > Option.get (List.find_index (( = ) "[Story] cp #4 leave: done") lines))
      lines
  in
  String.concat "\n" (after_events @ [ result ])

let with_abra coins =
  {
    Postcondition_check.nothing_read with
    party = Some [ Some "pidgey"; Some "abra" ];
    coins;
  }

let end_state_cases : Table_test.case list =
  [
    {
      name = "postconditions read and held: passed";
      input = (fun () -> run_with_end_state (with_abra (Some 20)));
      expectation =
        "read the end state\n\
         [Postcondition] cp party: passed: pidgey, abra\n\
         [Postcondition] cp coins: passed: 20\n\
         [Postcondition] cp: 2 passed, 0 failed, 0 not checked: passed\n\
         [Story] cp: done\n\
         passed";
    };
    {
      name = "a postcondition failed: stops, naming it, expected and read";
      input =
        (fun () ->
          run_with_end_state
            { (with_abra (Some 20)) with party = Some [ Some "pidgey" ] }
          |> last_line);
      expectation =
        "stopped: cp event 5 (postconditions): postconditions unmet: party: \
         failed: expected abra among the members, read pidgey";
    };
    {
      name = "a postcondition the game could not read: stops too";
      input = (fun () -> run_with_end_state (with_abra None) |> last_line);
      expectation =
        "stopped: cp event 5 (postconditions): postconditions unmet: coins: \
         not checked: the game can't read it";
    };
    {
      name = "a plan that states none: nothing read";
      input =
        (fun () ->
          run_with_end_state
            ~promised:{ promised with party = None; coins = None }
            Postcondition_check.nothing_read);
      expectation = "[Story] cp: done\npassed";
    };
    {
      name = "the end position fails first: nothing read";
      input =
        (fun () ->
          run_with_end_state
            ~end_at:(Grid { map = "Town"; tiles = [ tile 4 2 ]; facing = None })
            (with_abra (Some 20)));
      expectation =
        "[Story] cp end Town (4, 2): failed: declared end at Town (4, 2), but \
         the game reads no position\n\
         stopped: cp event 5 (end): declared end at Town (4, 2), but the game \
         reads no position";
    };
  ]

let () = Table_test.run "runner" (cases @ end_state_cases)
