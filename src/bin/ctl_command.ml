(* gamepilot ctl [--port N] [--owner LABEL] COMMAND
   gamepilot ctl [--port N] [--owner LABEL] run FILE

   Drives the console (or mGBA) by hand or from a script through the daemon,
   safely next to a running program: a command that presses takes the input
   lease (contracts v1.9) as [--owner] and is refused, naming the holder, while
   someone else holds it; reads (shot, read, status) need no lease. COMMAND and
   FILE's lines are Ctl_script's (labB.sh's format). [run] prints [ok N LINE]
   per line and stops at the first error. [park] and [resume] park the Switch
   on its HOME menu and resume the lab console's game from it, [close-game]
   and [start-game] close the running game and start one from a HOME tile
   (the fork's NintendoSwitch_GameEntry steps) (Console_park_command),
   [delete-save] goes to a game's red Delete Save Data button and
   [delete-save --confirm] presses it (Delete_save_command), [claim-gifts]
   claims PLZA's Mystery Gifts and boxes them (Claim_gifts_command) and
   [bank-home] moves them into Pokémon HOME (Bank_home_command). Every press
   is in the daemon's wire log with its owner. *)

(* The readers [read NAME] runs, one line each (Checkpoint_families). *)
let readers_usage () =
  String.concat ""
    (List.map
       (fun (r : Ctl_script.reader) ->
         Printf.sprintf "    %-11s %s\n" r.name r.doc)
       Checkpoint_families.ctl_readers)

(* The game park and resume go back to, as the usage names it. *)
let lab_title () =
  match Program_registry.lab_game_of_env () with
  | Ok (_, home) -> home.title
  | Error _ -> "the lab console's game"

let default_owner = "ctl"
let client = "gamepilot-ctl/0.1"

let usage =
  "  gamepilot ctl [--port N] [--owner LABEL] press A [--hold 100] [--wait \
   500] | dpad UP [N]\n\
  \      | wait MS | shot FILE.png | read READER | status\n\
  \      | park | resume  (the Switch: HOME menu and back to " ^ lab_title ()
  ^ ")\n\
    \      | close-game | start-game TILE  (the Switch, from HOME: close the\n\
    \        running game; start the game on TILE, 1 the first, 0 the cursor's)\n"
  ^ Delete_save_command.usage_line ^ Claim_gifts_command.usage_line
  ^ Bank_home_command.usage_line
  ^ "  gamepilot ctl [--port N] [--owner LABEL] run FILE\n    readers:\n"
  ^ readers_usage ()

type flags = { port : int; owner : string }

let rec parse_flags f = function
  | "--port" :: p :: rest -> (
      match int_of_string_opt p with
      | Some port -> parse_flags { f with port } rest
      | None -> Error ("bad --port " ^ p))
  | "--owner" :: o :: rest -> parse_flags { f with owner = o } rest
  | rest -> Ok (f, rest)

(* Script lines as (line number, text, step), blank and comment lines left
   out; the first line that does not parse is the error. *)
let parse_script lines =
  let rec go n acc = function
    | [] -> Ok (List.rev acc)
    | text :: rest -> (
        match Ctl_script.parse_line text with
        | Ok None -> go (n + 1) acc rest
        | Ok (Some step) -> go (n + 1) ((n, String.trim text, step) :: acc) rest
        | Error e -> Error (Printf.sprintf "line %d: %s" n e))
  in
  go 1 [] lines

let absolute file =
  if Filename.is_relative file then Filename.concat (Sys.getcwd ()) file
  else file

let print_fields =
  List.iter (fun (field, value) -> Printf.printf "%s: %s\n%!" field value)

(* Runs one step on the connection; [Error] stops the script. *)
let exec port (step : Ctl_script.step) =
  match step with
  | Press _ | Wait _ ->
      ignore (Effects.submit (Ctl_script.commands step) : Wire.batch_done);
      Ok ()
  | Shot file ->
      ignore (Effects.save_frame (absolute file) : int);
      Ok ()
  | Read name -> (
      match Checkpoint_families.ctl_reader name with
      | None -> Error ("unknown reader " ^ name)
      | Some reader ->
          print_fields (reader.read ());
          Ok ())
  | Status -> Result.map ignore (Status_command.show port)

let describe_error = function
  | Effects.Rpc_error e -> (
      match Wire.Lease.refusal e with
      | Some holder ->
          "refused: input lease held by " ^ Wire.Lease.describe holder
      | None -> Printf.sprintf "daemon error %d: %s" e.code e.message)
  | Effects.Disconnected why -> "disconnected: " ^ why
  | Unix.Unix_error (e, _, _) -> "no daemon: " ^ Unix.error_message e
  | Failure why -> why
  | e -> Printexc.to_string e

(* One step and its line: [ok N LINE], or [error N LINE: why] and [false]. *)
let step_line port (n, text, step) =
  let outcome =
    match exec port step with
    | result -> result
    | exception e -> Error (describe_error e)
  in
  match outcome with
  | Ok () ->
      Printf.printf "ok %d %s\n%!" n text;
      true
  | Error why ->
      Printf.printf "error %d %s: %s\n%!" n text why;
      false

(* Runs the steps in order and stops at the first error; exit code 0 or 1.
   The lease is taken first when any step presses. *)
let run_steps f steps =
  let all_ok () = List.for_all (step_line f.port) steps in
  let input = List.exists (fun (_, _, s) -> Ctl_script.sends_input s) steps in
  let lease = if input then Some (f.owner, None) else None in
  match Live.run ~port:f.port ~client ?lease all_ok with
  | true -> 0
  | false -> 1
  | exception e ->
      print_endline (describe_error e);
      1

let read_lines file = In_channel.with_open_text file In_channel.input_lines

let start_game f tile =
  match int_of_string_opt tile with
  | Some n when n >= 0 ->
      Ok
        (Console_park_command.on_port ~port:f.port ~owner:f.owner
           (`Start_game n))
  | _ ->
      Error
        ("ctl: start-game takes a tile, 1 the first (0 the cursor's): " ^ tile)

let main args =
  match
    parse_flags { port = Live.default_port; owner = default_owner } args
  with
  | Error e -> Error e
  | Ok (_, []) -> Error "ctl: no command"
  | Ok (f, [ "status" ]) -> Status_command.show f.port
  | Ok (f, [ "park" ]) ->
      Ok (Console_park_command.on_port ~port:f.port ~owner:f.owner `Park)
  | Ok (f, [ "resume" ]) ->
      Ok (Console_park_command.on_port ~port:f.port ~owner:f.owner `Resume)
  | Ok (f, [ "close-game" ]) ->
      Ok (Console_park_command.on_port ~port:f.port ~owner:f.owner `Close_game)
  | Ok (f, [ "start-game"; tile ]) -> start_game f tile
  | Ok (f, "delete-save" :: args) ->
      Delete_save_command.main ~port:f.port ~owner:f.owner args
  | Ok (f, "claim-gifts" :: args) ->
      Claim_gifts_command.main ~port:f.port ~owner:f.owner args
  | Ok (f, "bank-home" :: args) ->
      Bank_home_command.main ~port:f.port ~owner:f.owner args
  | Ok (f, [ "run"; file ]) -> (
      match parse_script (read_lines file) with
      | Ok steps -> Ok (run_steps f steps)
      | Error e -> Error (file ^ ": " ^ e)
      | exception Sys_error e -> Error e)
  | Ok (f, words) -> (
      match Ctl_script.parse_words words with
      | Ok step -> Ok (run_steps f [ (1, String.concat " " words, step) ])
      | Error e -> Error ("ctl: " ^ e))
