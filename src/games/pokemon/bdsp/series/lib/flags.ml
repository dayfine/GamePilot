type t = unit Run_flags.flags

let no_game_flags : unit Run_flags.game_flags =
  {
    game_defaults = ();
    game_switch = (fun () _ -> None);
    game_valued = (fun () _ _ -> Run_flags.Not_game_flag);
  }

let parse args =
  Run_flags.parse no_game_flags (Run_flags.defaults no_game_flags) args

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
        ("BDSP runs whole checkpoints in testing mode only: no "
       ^ String.concat ", " flags)
