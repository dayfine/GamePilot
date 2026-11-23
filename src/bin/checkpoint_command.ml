(* gamepilot checkpoint PLAN.json [--state FILE] [--port N] [--log FILE]
     [--party SPECIES,...] [--center TOWN] [--walk]
   gamepilot replay checkpoint WIRELOG PLAN.json [the same flags]

   Runs one checkpoint of a FireRed plan through the story runner. The state
   is loaded first and again on a reload; the party is the one at the
   checkpoint's start (FireRed reads no species yet). *)

type flags = {
  state : string option;
  port : int;
  log_file : string option;
  party : string;
  center : string option;
  walk : bool;
}

let usage =
  "  gamepilot checkpoint PLAN.json [--state FILE] [--port N] [--log FILE]\n\
  \      [--party SPECIES,...] [--center TOWN] [--walk]\n\
  \  gamepilot replay checkpoint WIRELOG PLAN.json [same flags]\n"

let defaults =
  {
    state = None;
    port = Live.default_port;
    log_file = None;
    party = "";
    center = None;
    walk = false;
  }

let rec parse flags = function
  | [] -> Ok flags
  | "--state" :: s :: rest -> parse { flags with state = Some s } rest
  | "--port" :: p :: rest -> (
      match int_of_string_opt p with
      | Some port -> parse { flags with port } rest
      | None -> Error ("bad --port " ^ p))
  | "--log" :: f :: rest -> parse { flags with log_file = Some f } rest
  | "--party" :: p :: rest -> parse { flags with party = p } rest
  | "--center" :: t :: rest -> parse { flags with center = Some t } rest
  | "--walk" :: rest -> parse { flags with walk = true } rest
  | a :: _ -> Error ("unknown argument " ^ a)

(* Every story line to stdout and, with --log, to the file. *)
let logger = function
  | None -> print_endline
  | Some path ->
      let out = open_out path in
      at_exit (fun () -> close_out out);
      fun line ->
        print_endline line;
        output_string out (line ^ "\n");
        flush out

let options flags : Frlg_story.Checkpoint_run.options =
  {
    state = flags.state;
    party = Frlg_actions.Party_roster.of_string flags.party;
    center = flags.center;
    gait = (if flags.walk then Walking else Running);
    log = logger flags.log_file;
  }

let ( let* ) = Result.bind

let prepare plan_file flags =
  let* plan = Story.Plan_decode.load plan_file in
  let* () = Frlg_story.Checkpoint_run.check_plan plan in
  let* world = Frlg_story.Checkpoint_run.load_world () in
  Ok (plan, world, options flags)

let report = function
  | Ok () ->
      print_endline "checkpoint: PASSED";
      0
  | Error failure ->
      print_endline ("checkpoint: FAILED " ^ Story.Failure.to_string failure);
      1

(* The checkpoint under [handle], its failures from the handler reported. *)
let handled handle run =
  match handle run with
  | result -> report result
  | exception Replay.Divergence e ->
      print_endline ("checkpoint: DIVERGED " ^ e);
      1
  | exception Effects.Disconnected e ->
      print_endline ("checkpoint: DISCONNECTED " ^ e);
      1
  | exception Unix.Unix_error (e, f, _) ->
      Printf.printf "checkpoint: CONNECT FAILED %s: %s\n" f
        (Unix.error_message e);
      1

(* Runs the checkpoint under [handle]; the exit code. *)
let run handle plan_file flags =
  match prepare plan_file flags with
  | Error e ->
      prerr_endline ("checkpoint: " ^ e);
      2
  | Ok (plan, world, options) ->
      handled handle (fun () ->
          Frlg_story.Checkpoint_run.run options world plan)

let live plan_file args =
  Result.map
    (fun flags -> run (Live.run ~port:flags.port) plan_file flags)
    (parse defaults args)

let replay wirelog plan_file args =
  Result.map
    (fun flags -> run (Replay.run (Replay.log_of_file wirelog)) plan_file flags)
    (parse defaults args)
