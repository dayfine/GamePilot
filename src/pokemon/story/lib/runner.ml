let failure_at (checkpoint : Plan.checkpoint) index (event : Plan.event) reason
    =
  {
    Failure.checkpoint_id = checkpoint.checkpoint_id;
    event_index = index;
    event_id = event.id;
    reason;
  }

(* The name of the game action the event needs and the game lacks. *)
let missing_action (game : Game.t) (event : Plan.event) =
  match (event.kind, event.action) with
  | Game_action _, Some name when not (List.mem_assoc name game.game_actions) ->
      Some name
  | _ -> None

let missing_at game checkpoint index event =
  Option.map
    (fun name -> failure_at checkpoint index event (No_handler name))
    (missing_action game event)

let missing_handler game (checkpoint : Plan.checkpoint) =
  List.find_map Fun.id
    (List.mapi (missing_at game checkpoint) checkpoint.events)

let dispatch (game : Game.t) (event : Plan.event) =
  match (event.kind, event.action) with
  | Route route, _ -> game.walk_route event route
  | Game_action args, Some name ->
      (List.assoc name game.game_actions) event args
  | _ -> game.run_builtin event

(* The event's declared_after against where the game reads the player. *)
let check_declared (game : Game.t) (event : Plan.event) =
  match (event.declared_after, game.position ()) with
  | Some (Grid declared), Some observed
    when not (Pose.matches declared observed) ->
      Error (Failure.Not_at_declared { declared; observed })
  | _ -> Ok ()

let run_event (game : Game.t) notify line (event : Plan.event) =
  game.log
    (line (if event.why = "" then "start" else "start (" ^ event.why ^ ")"));
  notify Event_progress.Started;
  match dispatch game event with
  | exception error ->
      let reason = Printexc.to_string error in
      game.log (line ("failed: " ^ reason));
      notify (Event_progress.Failed reason);
      raise error
  | Error cause -> Error (Failure.Handler cause)
  | Ok () -> check_declared game event

let log_end (game : Game.t) notify line = function
  | Ok () ->
      game.log (line "done");
      notify Event_progress.Passed
  | Error reason ->
      let reason = Failure.reason_to_string reason in
      game.log (line ("failed: " ^ reason));
      notify (Event_progress.Failed reason)

let step ~on_event (game : Game.t) (checkpoint : Plan.checkpoint) index
    (event : Plan.event) =
  let notify = on_event index in
  let line text =
    Printf.sprintf "[Story] %s #%d %s: %s" checkpoint.checkpoint_id (index + 1)
      event.id text
  in
  match List.find_opt game.flag_holds event.skip_if with
  | Some flag ->
      game.log (line ("skipped (" ^ flag ^ ")"));
      notify (Event_progress.Skipped flag);
      Ok ()
  | None ->
      let result = run_event game notify line event in
      log_end game notify line result;
      Result.map_error (failure_at checkpoint index event) result

(* The end check's verdict: [Ok] or the failure reason. *)
let end_verdict (game : Game.t) declared =
  match game.position () with
  | Some observed when Pose.matches declared observed -> Ok ()
  | observed -> Error (Failure.Not_at_end { declared; observed })

(* After the last event: the player stands at [declared]. *)
let check_end (game : Game.t) (checkpoint : Plan.checkpoint) index declared =
  let id = checkpoint.checkpoint_id in
  let line text =
    Printf.sprintf "[Story] %s end %s: %s" id
      (Pose.grid_to_string declared)
      text
  in
  let verdict = end_verdict game declared in
  game.log
    (line
       (match verdict with
       | Ok () -> "holds"
       | Error reason -> "failed: " ^ Failure.reason_to_string reason));
  Result.map_error
    (fun reason ->
      {
        Failure.checkpoint_id = id;
        event_index = index;
        event_id = "end";
        reason;
      })
    verdict

let unmet_failure (checkpoint : Plan.checkpoint) index unmet =
  {
    Failure.checkpoint_id = checkpoint.checkpoint_id;
    event_index = index;
    event_id = "postconditions";
    reason =
      Unmet_postconditions (List.map Postcondition_check.result_to_string unmet);
  }

(* After the end position: the plan's postconditions, read and checked. *)
let check_postconditions (game : Game.t) (checkpoint : Plan.checkpoint) index
    (promised, observe) =
  let results = Postcondition_check.check promised (observe promised) in
  List.iter game.log
    (Postcondition_check.log_lines checkpoint.checkpoint_id results);
  match Postcondition_check.unmet results with
  | [] -> Ok ()
  | unmet -> Error (unmet_failure checkpoint index unmet)

(* The plan states something beyond the position to check. *)
let states_end_state (p : Plan.postconditions) =
  p.party <> None || p.items <> [] || p.coins <> None || p.money <> None
  || p.flags <> []

let check_end_position game checkpoint index = function
  | None -> Ok ()
  | Some declared -> check_end game checkpoint index declared

let check_end_state game checkpoint index = function
  | Some ((promised, _) as checks) when states_end_state promised ->
      check_postconditions game checkpoint index checks
  | _ -> Ok ()

let finish (game : Game.t) checkpoint index ~end_at ~end_state =
  let checked =
    Result.bind (check_end_position game checkpoint index end_at) (fun () ->
        check_end_state game checkpoint index end_state)
  in
  if Result.is_ok checked then
    game.log ("[Story] " ^ checkpoint.Plan.checkpoint_id ^ ": done");
  checked

let rec run_from ~on_event (game : Game.t) checkpoint ~end_at ~end_state index =
  function
  | [] -> finish game checkpoint index ~end_at ~end_state
  | event :: rest ->
      Result.bind (step ~on_event game checkpoint index event) (fun () ->
          run_from ~on_event game checkpoint ~end_at ~end_state (index + 1) rest)

let run ?end_at ?end_state ?(on_event = fun _ _ -> ()) (game : Game.t)
    (checkpoint : Plan.checkpoint) =
  let id = checkpoint.checkpoint_id in
  match missing_handler game checkpoint with
  | Some failure ->
      game.log ("[Story] " ^ id ^ ": not started: " ^ Failure.to_string failure);
      Error failure
  | None ->
      game.log
        (Printf.sprintf "[Story] %s: start, %d events" id
           (List.length checkpoint.events));
      run_from ~on_event game checkpoint ~end_at ~end_state 0 checkpoint.events
