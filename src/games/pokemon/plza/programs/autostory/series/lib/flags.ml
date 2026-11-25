module Options = Plza_autostory.New_game_options

type t = Options.t Run_flags.flags

let ( let* ) = Result.bind

let option_keys : Options.t Run_flags.option_keys =
  {
    unset = Options.none;
    keys =
      [
        ("language", Options.language);
        ("look", Options.look);
        ("name", Options.name);
      ];
  }

(* No flag of PLZA's own: its options ride in --options. *)
let no_game_flags : unit Run_flags.game_flags =
  {
    game_defaults = ();
    game_switch = (fun () _ -> None);
    game_valued = (fun () _ _ -> None);
  }

let parse args =
  let* f =
    Run_flags.parse no_game_flags (Run_flags.defaults no_game_flags) args
  in
  let* options = Run_flags.read_options option_keys f.options in
  let* () = Options.check options in
  Ok { f with game = options }

let usage =
  "  gamepilot run plza.autostory --from ID --to ID --mode testing\n\
  \      --backend switch --serial PORT --capture DEVICE [--runs N] [--watch]\n"

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
