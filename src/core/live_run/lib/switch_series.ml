(* Shared Switch-only testing-mode series plumbing: initial-screen check,
   session guard, failure frame capture, run summary formatting, and
   testing-mode Series_daemons lifecycle. *)

let ending_of ~result_of name outcome =
  Series_daemons.format_ending ~name (result_of outcome)

let run_guarded ~failed ~already_at_start ~log ~picture ~expectation report body
    =
  let end_failed () = Watch_report.end_run report ~passed:false in
  match
    Switch.Initial_screen.check_unless_chained ~already_at_start ~log ~picture
      expectation
  with
  | Error reason ->
      end_failed ();
      failed ~repeats:true ~at:"start" ~reason
  | Ok () ->
      Daemon_run.guard_session
        ~on_stop:(fun reason ->
          end_failed ();
          failed ~repeats:true ~at:"stopped" ~reason)
        ~on_raised:(fun e ->
          end_failed ();
          failed ~repeats:false ~at:"raised" ~reason:(Printexc.to_string e))
        body

let in_session ~already_at_start ~expectation ~create_report ~failed ~result_of
    body ~log record (backend : Wire.backend) =
  let picture = backend.viewport in
  let log = Watch_report.log log in
  let report = create_report () in
  let outcome =
    run_guarded ~failed ~already_at_start ~log ~picture ~expectation report
      (fun () -> body ~log ~picture report)
  in
  if Result.is_error (result_of outcome) then
    Daemon_run.save_failure ~log record ~save_states:false;
  outcome

let run_attempt ~daemons ~runs_dir ~checkpoint_id ~n ~attempt
    ?(banner_suffix = "") ~already_at_start ~expectation ~create_report ~failed
    ~result_of body =
  let name = Series_daemons.run_name ~id:checkpoint_id ~n ~attempt () in
  let banner = "[Run] " ^ name ^ banner_suffix in
  let of_runner ({ at; reason; repeats } : Daemon_run.failed) =
    failed ~repeats ~at ~reason
  in
  match
    Series_daemons.start_and_run daemons ~runs_dir ~checkpoint:checkpoint_id
      ~mode:"testing" ~n ~failed:of_runner
      ~ending:(ending_of ~result_of name)
      ~banner
      (in_session ~already_at_start ~expectation ~create_report ~failed
         ~result_of body)
  with
  | Error reason -> failed ~repeats:true ~at:"run folder" ~reason
  | Ok (_, outcome) -> outcome

let run_series ~daemon ~runs_dir ~backend ~viewport ?program_flags ~daemon_flags
    ~port ~watch ~close_game ~info ~checkpoints body =
  let daemons =
    Series_daemons.create_for_runs ~daemon ~runs_dir ~backend ~viewport
      ?program_flags ~daemon_flags ~port ~watch
      { info; mode = "testing"; checkpoints }
  in
  let passed = body daemons in
  Series_daemons.finish_series daemons ~close_game ~passed ()
