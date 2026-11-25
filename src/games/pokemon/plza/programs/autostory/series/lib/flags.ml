module Options = Plza_autostory.New_game_options

type t = Options.t Checkpoints_flags.flags

let ( let* ) = Result.bind

let game_flags : Options.t Checkpoints_flags.game_flags =
  {
    game_defaults = Options.none;
    game_switch = (fun _ _ -> None);
    game_valued = Options.valued;
  }

let parse args =
  let* f =
    Checkpoints_flags.parse game_flags
      (Checkpoints_flags.defaults game_flags)
      args
  in
  let* () = Options.check f.game in
  Ok f

let usage =
  "  gamepilot checkpoints --program plza.autostory --from ID --to ID --mode \
   testing\n\
  \      --backend switch --serial PORT --capture DEVICE [--runs N] [--watch]\n"
  ^ Options.usage

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
