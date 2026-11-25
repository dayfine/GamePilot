open Engine_postcondition

module Make (T : Engine_terms.TERMS) (Raw : Engine_plan.Plan.RAW) = struct
  module Plan = Engine_plan.Plan.Make (T) (Raw)
  module Game = Game.Make (T) (Raw)
  module Failure = Failure.Make (T)
  module Log_line = Log_line.Make (T)

  let failure_at (checkpoint : Plan.checkpoint) index (event : Plan.event)
      reason =
    {
      Failure.checkpoint_id = checkpoint.checkpoint_id;
      event_index = index;
      event_id = event.id;
      reason;
    }

  (* The name of the game action the event needs and the game lacks. *)
  let missing_action (game : Game.t) (event : Plan.event) =
    match (event.kind, event.action) with
    | Game_action _, Some name when not (List.mem_assoc name game.game_actions)
      ->
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
    | Own own, _ -> game.run_own event own
    | Game_action args, Some name ->
        (List.assoc name game.game_actions) event args
    | _ -> game.run_builtin event

  (* The event's declared_after against where the game reads the player. *)
  let check_declared (game : Game.t) (event : Plan.event) =
    match (event.declared_after, game.position ()) with
    | Some declared, Some observed when not (T.Pose.matches declared observed)
      ->
        Error (Failure.Not_at_declared { declared; observed })
    | _ -> Ok ()

  let text words : Log_line.t = [ Text words ]

  let run_event ~say (game : Game.t) notify line (event : Plan.event) =
    say
      (line
         (text
            (if event.why = "" then "start" else "start (" ^ event.why ^ ")")));
    notify Event_progress.Started;
    match dispatch game event with
    | exception error ->
        let reason = text (Printexc.to_string error) in
        say (line (Text "failed: " :: reason));
        notify (Event_progress.Failed reason);
        raise error
    | Error cause -> Error (Failure.Handler cause)
    | Ok () -> check_declared game event

  let log_end ~say notify line = function
    | Ok () ->
        say (line (text "done"));
        notify Event_progress.Passed
    | Error reason ->
        let reason : Log_line.t = [ Reason reason ] in
        say (line (Text "failed: " :: reason));
        notify (Event_progress.Failed reason)

  let step ~say ~on_event (game : Game.t) (checkpoint : Plan.checkpoint) index
      (event : Plan.event) =
    let notify = on_event index in
    let line rest : Log_line.t =
      Text
        (Printf.sprintf "[Story] %s #%d %s: " checkpoint.checkpoint_id
           (index + 1) event.id)
      :: rest
    in
    match List.find_opt game.flag_holds event.skip_if with
    | Some flag ->
        say (line (text ("skipped (" ^ flag ^ ")")));
        notify (Event_progress.Skipped flag);
        Ok ()
    | None ->
        let result = run_event ~say game notify line event in
        log_end ~say notify line result;
        Result.map_error (failure_at checkpoint index event) result

  (* The end check's verdict: [Ok] or the failure reason. *)
  let end_verdict (game : Game.t) declared =
    match game.position () with
    | Some observed when T.Pose.matches declared observed -> Ok ()
    | observed -> Error (Failure.Not_at_end { declared; observed })

  (* After the last event: the player stands at [declared]. *)
  let check_end ~say (game : Game.t) (checkpoint : Plan.checkpoint) index
      declared =
    let id = checkpoint.checkpoint_id in
    let verdict = end_verdict game declared in
    say
      (Log_line.Text ("[Story] " ^ id ^ " end ")
      :: Pose declared
      ::
      (match verdict with
      | Ok () -> [ Text ": holds" ]
      | Error reason -> [ Text ": failed: "; Reason reason ]));
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
      reason = Unmet_postconditions unmet;
    }

  (* After the end position: the plan's postconditions, read and checked. *)
  let check_postconditions ~say (checkpoint : Plan.checkpoint) index
      (promised, observe) =
    let results = T.Postconditions.check promised (observe promised) in
    List.iter
      (fun line -> say (text line))
      (Postcondition.log_lines ~tag:"Postcondition" checkpoint.checkpoint_id
         results);
    match Postcondition.unmet results with
    | [] -> Ok ()
    | unmet -> Error (unmet_failure checkpoint index unmet)

  let check_end_position ~say game checkpoint index = function
    | None -> Ok ()
    | Some declared -> check_end ~say game checkpoint index declared

  let check_end_state ~say checkpoint index = function
    | Some checks -> check_postconditions ~say checkpoint index checks
    | None -> Ok ()

  let finish ~say (game : Game.t) checkpoint index ~end_at ~end_state =
    let checked =
      Result.bind (check_end_position ~say game checkpoint index end_at)
        (fun () -> check_end_state ~say checkpoint index end_state)
    in
    if Result.is_ok checked then
      say (text ("[Story] " ^ checkpoint.Plan.checkpoint_id ^ ": done"));
    checked

  (* A partial run that stops before the last event checks no end: the player
     is not there. *)
  let finish_partial ~say checkpoint index =
    say
      (text
         (Printf.sprintf
            "[Story] %s: stopped after #%d (--to-event): end not checked"
            checkpoint.Plan.checkpoint_id index));
    Ok ()

  let rec run_from ~say ~on_event (game : Game.t) checkpoint ~ends index =
    function
    | [] -> (
        match ends with
        | Some (end_at, end_state) ->
            finish ~say game checkpoint index ~end_at ~end_state
        | None -> finish_partial ~say checkpoint index)
    | (i, event) :: rest ->
        Result.bind (step ~say ~on_event game checkpoint i event) (fun () ->
            run_from ~say ~on_event game checkpoint ~ends (i + 1) rest)

  let event_ids (checkpoint : Plan.checkpoint) =
    List.map (fun (e : Plan.event) -> e.id) checkpoint.events

  let start_line (checkpoint : Plan.checkpoint) = function
    | None ->
        Printf.sprintf "[Story] %s: start, %d events" checkpoint.checkpoint_id
          (List.length checkpoint.events)
    | Some range ->
        let first, last = Event_range.describe range (event_ids checkpoint) in
        Printf.sprintf "[Story] %s: start at %s, to %s, of %d events"
          checkpoint.checkpoint_id first last
          (List.length checkpoint.events)

  let not_started id failure : Log_line.t =
    [ Text ("[Story] " ^ id ^ ": not started: "); Failure failure ]

  let run ?end_at ?end_state ?(on_event = fun _ _ -> ()) ?events ~say
      (game : Game.t) (checkpoint : Plan.checkpoint) =
    let id = checkpoint.checkpoint_id in
    match missing_handler game checkpoint with
    | Some failure ->
        say (not_started id failure);
        Error failure
    | None ->
        say (text (start_line checkpoint events));
        let range =
          Option.value events ~default:{ Event_range.first = 0; last = None }
        in
        let ends =
          if Event_range.reaches_end range checkpoint.events then
            Some (end_at, end_state)
          else None
        in
        run_from ~say ~on_event game checkpoint ~ends range.first
          (Event_range.select range checkpoint.events)
end
