type t = {
  from_id : string;
  to_id : string;
  runs : int option;
  runs_dir : string;
  daemon : string;
  backend_name : string;
  watch : Live_run.Daemon_process.watch option;
  daemon_flags : string list;
  program : (string * string) list;
}

type others = {
  mode : Engine_run.Checkpoint_trials.mode option;
  preflight : bool;
  from_event : string option;
  to_event : string option;
}

let takes (o : others) =
  let refused =
    List.filter_map
      (fun (given, flag) -> if given then Some flag else None)
      [
        ( o.mode <> None && o.mode <> Some Engine_run.Checkpoint_trials.Testing,
          "--mode" );
        (o.preflight, "--preflight");
        (o.from_event <> None, "--from-event");
        (o.to_event <> None, "--to-event");
      ]
  in
  match refused with
  | [] -> Ok ()
  | flags ->
      Error
        ("PLZA runs whole checkpoints in testing mode only: no "
       ^ String.concat ", " flags)
