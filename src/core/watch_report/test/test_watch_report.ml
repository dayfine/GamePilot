(* What a run sends the watch page through Watch_report, on a scripted
   session that records the page's notifications: the plan at each step's
   change, the story lines and the run, in order. (A plan's run, the
   pre-flight's among them: Frlg_story's test_plan_watch.) *)

module R = Watch_report
module W = Wire.Watch

let state_name = function
  | W.Pending -> "pending"
  | Current -> "current"
  | Done -> "done"
  | Failed -> "failed"
  | Skipped -> "skipped"

let run_state_name = Wire.Watch_run.string_of_state

let event (e : W.plan_event) =
  e.id ^ "=" ^ state_name e.state
  ^ if e.detail = "" then "" else "(" ^ e.detail ^ ")"

let run_line (r : Wire.Watch_run.t) =
  String.concat " "
    (("run " ^ r.mode)
    :: List.map
         (fun (c : Wire.Watch_run.checkpoint) ->
           c.id ^ "=" ^ run_state_name c.state)
         r.checkpoints)

(* Runs [f] and returns what the page got, one line per notification. *)
let page f =
  let sent = ref [] in
  let add line = sent := line :: !sent in
  let effc : type a.
      a Effect.t -> ((a, unit) Effect.Deep.continuation -> unit) option =
    function
    | Effects.Show_plan p ->
        Some
          (fun k ->
            add
              ("plan " ^ p.checkpoint ^ ": "
              ^ String.concat " " (List.map event p.events));
            Effect.Deep.continue k ())
    | Effects.Show_log line ->
        Some
          (fun k ->
            add ("log " ^ line);
            Effect.Deep.continue k ())
    | Effects.Show_run r ->
        Some
          (fun k ->
            add (run_line r);
            Effect.Deep.continue k ())
    | _ -> None
  in
  (match Effect.Deep.try_with f () { effc } with
  | () -> ()
  | exception Failure why -> add ("raised " ^ why));
  String.concat "\n" (List.rev !sent)

(* The step-list form, as [gamepilot run <program>] plays it: one step,
   failed when the program's outcome is a failure, its line logged. *)
let program ~outcome () =
  let t = R.create ~checkpoint:"start_menu_poc" [ "run" ] in
  R.start_run t ~mode:"run";
  match R.step t "run" outcome with
  | line ->
      let passed = String.starts_with ~prefix:"PASS" line in
      if not passed then R.set t 0 W.Failed line;
      R.log ignore line;
      R.end_run t ~passed
  | exception e ->
      R.end_run t ~passed:false;
      raise e

let opening =
  [
    "plan start_menu_poc: run=pending";
    "run run start_menu_poc=current";
    "plan start_menu_poc: run=current";
  ]

(* Times: a step that ran has its start and end, one not run has neither. *)
let times () =
  let plan = ref [] in
  let effc : type a.
      a Effect.t -> ((a, unit) Effect.Deep.continuation -> unit) option =
    function
    | Effects.Show_plan p ->
        Some
          (fun k ->
            plan := p.events;
            Effect.Deep.continue k ())
    | _ -> None
  in
  Effect.Deep.try_with
    (fun () ->
      let t = R.create ~checkpoint:"mg-00" [ "soft_reset"; "read_summaries" ] in
      R.step t "soft_reset" ignore)
    () { effc };
  String.concat " "
    (List.map
       (fun (e : W.plan_event) ->
         Printf.sprintf "%s:%b,%b" e.id (e.started_ms <> None)
           (e.ended_ms <> None))
       !plan)

let () =
  Table_test.run "watch_report"
    [
      {
        name = "a program that passes";
        input = (fun () -> page (program ~outcome:(fun () -> "PASS open")));
        expectation =
          String.concat "\n"
            (opening
            @ [
                "plan start_menu_poc: run=done";
                "log PASS open";
                "run run start_menu_poc=passed";
              ]);
      };
      {
        name = "a program whose outcome is a failure";
        input = (fun () -> page (program ~outcome:(fun () -> "FAIL no menu")));
        expectation =
          String.concat "\n"
            (opening
            @ [
                "plan start_menu_poc: run=done";
                "plan start_menu_poc: run=failed(FAIL no menu)";
                "log FAIL no menu";
                "run run start_menu_poc=failed";
              ]);
      };
      {
        name = "a program that raises: its step failed with the exception";
        input =
          (fun () ->
            page (program ~outcome:(fun () -> failwith "disconnected")));
        expectation =
          String.concat "\n"
            (opening
            @ [
                {|plan start_menu_poc: run=failed(Failure("disconnected"))|};
                "run run start_menu_poc=failed";
                "raised disconnected";
              ]);
      };
      {
        name = "a step that ran has its times, one not run has none";
        input = times;
        expectation = "soft_reset:true,true read_summaries:false,false";
      };
    ]
