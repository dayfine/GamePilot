module Options = Plza_autostory.New_game_options

type t = Options.t Run_flags.flags

let ( let* ) = Result.bind

let option_keys =
  [
    ("language", Options.language);
    ("look", Options.look);
    ("name", Options.name);
  ]

(* One --options KEY=VALUE: the value keeps any later [=] and commas. *)
let option_pair text =
  match String.index_opt text '=' with
  | Some 0 -> Error ("--options: an empty key in " ^ text)
  | None when text = "" -> Error "--options: an empty KEY=VALUE"
  | None -> Error ("--options: " ^ text ^ " has no =VALUE")
  | Some i ->
      Ok
        ( String.sub text 0 i,
          String.sub text (i + 1) (String.length text - i - 1) )

(* Each --options adds its pair, after those given before it. *)
let add_option pairs text =
  let* key, value = option_pair text in
  if List.mem_assoc key pairs then
    Error ("--options: " ^ key ^ " is given twice")
  else Ok (pairs @ [ (key, value) ])

let game_flags : (string * string) list Run_flags.game_flags =
  {
    game_defaults = [];
    game_switch = (fun _ _ -> None);
    game_valued =
      (fun pairs name text ->
        if name = "--options" then Some (add_option pairs text) else None);
  }

let usage =
  "  gamepilot run plza.autostory ... [--options KEY=VALUE]...\n\
  \      (00-new-game's choices, one pair each: language=TAG, look=1..8, \
   name=NAME)\n"

let read_option acc (key, value) =
  let* options = acc in
  match List.assoc_opt key option_keys with
  | None ->
      Error
        ("--options: autostory takes "
        ^ String.concat ", " (List.map fst option_keys)
        ^ ", not " ^ key)
  | Some read ->
      Result.map_error (fun e -> "--options " ^ e) (read options value)

let parse args =
  let* f = Run_flags.parse game_flags (Run_flags.defaults game_flags) args in
  let* options = List.fold_left read_option (Ok Options.none) f.game in
  let* () = Options.check options in
  Ok { f with game = options }

let takes (f : t) =
  let refused =
    List.filter_map
      (fun (given, flag) -> if given then Some flag else None)
      [
        ( f.mode <> None && f.mode <> Some Engine_run.Checkpoint_trials.Testing,
          "--mode" );
        (f.preflight, "--preflight");
        (f.from_event <> None, "--from-event");
        (f.to_event <> None, "--to-event");
        (f.max_rounds <> None, "--max-rounds");
      ]
  in
  match refused with
  | [] -> Ok ()
  | flags ->
      Error
        ("PLZA runs whole checkpoints in testing mode only: no "
       ^ String.concat ", " flags)
