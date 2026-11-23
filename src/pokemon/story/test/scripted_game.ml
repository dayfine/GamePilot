(* A game whose handlers follow a script instead of a console: every handler
   and runner line goes to one log, handlers fail where the script says, and
   the player is read where the script puts them after each event. *)

open Story

type script = {
  fails : (string * Failure.cause) list;
      (* Event id -> what its handler reports. *)
  actions : string list; (* The game actions it implements. *)
  flags : string list; (* Flags that hold. *)
  read_after : (string * Pose.observed) list;
      (* Event id -> where the player reads after it; elsewhere unknown. *)
}

let script = { fails = []; actions = []; flags = []; read_after = [] }

let make script =
  let lines = ref [] and last = ref "" in
  let log line = lines := line :: !lines in
  let handle what (event : Plan.event) =
    log (what ^ " " ^ event.id);
    last := event.id;
    match List.assoc_opt event.id script.fails with
    | Some cause -> Error cause
    | None -> Ok ()
  in
  let action name =
    (name, fun event _args -> handle ("action " ^ name) event)
  in
  let chore name () =
    log name;
    Ok ()
  in
  let game : Game.t =
    {
      walk_route = (fun event _ -> handle "walk" event);
      run_builtin = handle "builtin";
      game_actions = List.map action script.actions;
      flag_holds = (fun flag -> List.mem flag script.flags);
      position = (fun () -> List.assoc_opt !last script.read_after);
      heal = chore "heal";
      save = chore "save";
      reload = chore "reload";
      log;
    }
  in
  (game, fun () -> String.concat "\n" (List.rev !lines))
