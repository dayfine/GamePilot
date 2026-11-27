(* Shared live-run helpers: Daemon_run.guard_attempt,
   Daemon_run.check_initial_screen (skip path), and Series_daemons.run_name.
   Fakes are pure callbacks returning or raising scripted outcomes. *)

let check_eq name ~show ~expected ~actual =
  Table_test.report name
    (if actual = expected then Ok ()
     else
       Error
         (Printf.sprintf "expected %s, got %s" (show expected) (show actual)))

type outcome = Passed | Failed of Daemon_run.failed

let show_outcome = function
  | Passed -> "Passed"
  | Failed { at; reason; repeats } ->
      Printf.sprintf "Failed {at=%S; reason=%S; repeats=%b}" at reason repeats

let show_unit_res = function
  | Ok () -> "Ok ()"
  | Error e -> Printf.sprintf "Error %S" e

let failed f = Failed f

let () =
  (* Series_daemons.run_name *)
  check_eq "run_name omits attempt on attempt 1" ~show:Fun.id
    ~expected:"03.07 run 1"
    ~actual:(Series_daemons.run_name ~id:"03.07" ~n:1 ~attempt:1);
  check_eq "run_name includes attempt after attempt 1" ~show:Fun.id
    ~expected:"03.07 run 2 attempt 3"
    ~actual:(Series_daemons.run_name ~id:"03.07" ~n:2 ~attempt:3);

  (* Daemon_run.guard_attempt: normal return *)
  check_eq "guard_attempt returns body outcome" ~show:show_outcome
    ~expected:Passed
    ~actual:(Daemon_run.guard_attempt ~failed (fun () -> Passed));

  (* Daemon_run.guard_attempt: Stop_requested *)
  let stopped = ref None in
  let out_stop =
    Daemon_run.guard_attempt ~failed
      ~on_stop:(fun why -> stopped := Some why)
      (fun () -> raise (Effects.Stop_requested "user clicked stop"))
  in
  check_eq "guard_attempt turns Stop_requested into repeating failure"
    ~show:show_outcome
    ~expected:
      (Failed { at = "stopped"; reason = "user clicked stop"; repeats = true })
    ~actual:out_stop;
  check_eq "guard_attempt invokes on_stop"
    ~show:(function None -> "None" | Some s -> Printf.sprintf "Some %S" s)
    ~expected:(Some "user clicked stop") ~actual:!stopped;

  (* Daemon_run.guard_attempt: unexpected exception *)
  let exn_called = ref false in
  let out_exn =
    Daemon_run.guard_attempt ~failed
      ~on_exn:(fun () -> exn_called := true)
      (fun () -> raise (Failure "boom"))
  in
  check_eq "guard_attempt turns unexpected exception into non-repeating failure"
    ~show:show_outcome
    ~expected:
      (Failed { at = "raised"; reason = "Failure(\"boom\")"; repeats = false })
    ~actual:out_exn;
  check_eq "guard_attempt invokes on_exn" ~show:string_of_bool ~expected:true
    ~actual:!exn_called;

  (* Daemon_run.guard_attempt: Disconnected is re-raised *)
  let disconnected =
    match
      Daemon_run.guard_attempt ~failed (fun () ->
          raise (Effects.Disconnected "eof"))
    with
    | _ -> None
    | exception Effects.Disconnected why -> Some why
  in
  check_eq "guard_attempt re-raises Disconnected"
    ~show:(function None -> "None" | Some s -> Printf.sprintf "Some %S" s)
    ~expected:(Some "eof") ~actual:disconnected;

  (* Daemon_run.check_initial_screen: skips when already_at_start = true *)
  let logged = ref [] in
  let picture : Wire.box = { x = 0.; y = 0.; w = 1.; h = 1. } in
  let res =
    Daemon_run.check_initial_screen
      ~log:(fun s -> logged := s :: !logged)
      ~picture ~already_at_start:true Switch.Initial_screen.In_game_read_only
  in
  check_eq "check_initial_screen skips when already_at_start"
    ~show:show_unit_res ~expected:(Ok ()) ~actual:res;
  check_eq "check_initial_screen logs skip line" ~show:string_of_int ~expected:1
    ~actual:(List.length !logged);

  Table_test.finish ()
