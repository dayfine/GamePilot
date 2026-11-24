(* What a shadow plan shows on the watch page when it runs through the
   checkpoint runner (Plan_watch.run_shadow), on a scripted session that
   records the page's notifications: the plan at each step's change, the
   story lines and the run, in order. The pre-flight's plan is played with
   scripted steps: it reads a full party (six lines) and passes; its return
   to the save fails; its verdict is a mismatch. *)

open Frlg_story
module W = Wire.Watch

let state_name = function
  | W.Pending -> "pending"
  | Current -> "current"
  | Done -> "done"
  | Failed -> "failed"
  | Skipped -> "skipped"

let event (e : W.plan_event) =
  e.id ^ "=" ^ state_name e.state
  ^ if e.detail = "" then "" else "(" ^ e.detail ^ ")"

let run_line (r : Wire.Watch_run.t) =
  String.concat " "
    (("run " ^ r.mode)
    :: List.map
         (fun (c : Wire.Watch_run.checkpoint) ->
           c.id ^ "=" ^ Wire.Watch_run.string_of_state c.state)
         r.checkpoints)

(* Answers the session's effects with no game behind them (no frame ever
   arrives) and records what goes to the page. *)
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
    | Effects.Subscribe specs ->
        Some
          (fun k ->
            Effect.Deep.continue k
              (List.map (fun (s : Wire.probe_spec) -> s.id) specs))
    | Effects.Unsubscribe ids -> Some (fun k -> Effect.Deep.continue k ids)
    | Effects.Read -> Some (fun k -> Effect.Deep.continue k None)
    | Effects.Now -> Some (fun k -> Effect.Deep.continue k 0.)
    | _ -> None
  in
  Effect.Deep.try_with f () { effc };
  String.concat "\n" (List.rev !sent)

let world = lazy (Result.get_ok (Checkpoint_run.load_world ()))

let plan =
  Shadow_plan.plan ~id:"mg-01" ~title:"pre-flight of mg-01"
    Shadow_plan.preflight_steps

let party =
  [
    "Charizard L50";
    "Pidgeot L40";
    "Snorlax L45";
    "Lapras L42";
    "Eevee L30";
    "Mew L5";
  ]

(* The pre-flight's steps, scripted: [back] the return to the save,
   [verdict] the table's. *)
let actions ~back ~verdict log =
  let step f : Story.Game.game_action = fun _ _ -> f () in
  let ok () = Ok () in
  [
    ("soft_reset", step back);
    ("check_start", step ok);
    ( "read_party",
      step (fun () ->
          List.iter log party;
          Ok ()) );
    ("read_trainer_card", step ok);
    ("verdict", step verdict);
  ]

let preflight ~back ~verdict () =
  ignore
    (Plan_watch.run_shadow ~mode:"preflight" ~log:ignore (Lazy.force world) plan
       (actions ~back ~verdict)
      : (unit, Story.Failure.t) result)

let plan_line states =
  "plan mg-01: "
  ^ String.concat " "
      (List.map2 (fun id s -> id ^ "=" ^ s) Shadow_plan.preflight_steps states)

let p = "pending"
and c = "current"
and d = "done"

(* The runner's own story lines ("[Story] ...") go to the page too; left out
   here, as they are the runner's. *)
let only_page lines =
  List.filter (fun l -> not (String.starts_with ~prefix:"log [" l)) lines

let shown f =
  String.concat "\n" (only_page (String.split_on_char '\n' (page f)))

let full_party_pass =
  String.concat "\n"
    ([
       plan_line [ p; p; p; p; p ];
       "run preflight mg-01=current";
       plan_line [ c; p; p; p; p ];
       plan_line [ d; p; p; p; p ];
       plan_line [ d; c; p; p; p ];
       plan_line [ d; d; p; p; p ];
       plan_line [ d; d; c; p; p ];
     ]
    @ List.map (fun m -> "log " ^ m) party
    @ [
        plan_line [ d; d; d; p; p ];
        plan_line [ d; d; d; c; p ];
        plan_line [ d; d; d; d; p ];
        plan_line [ d; d; d; d; c ];
        plan_line [ d; d; d; d; d ];
        "run preflight mg-01=passed";
      ])

let not_back =
  Error (Story.Failure.cause ~repeats:true "not_back" "no start state")

let last n text =
  let lines = String.split_on_char '\n' text in
  String.concat "\n"
    (List.filteri (fun i _ -> i >= List.length lines - n) lines)

let () =
  Table_test.run "plan_watch"
    [
      {
        name = "the pre-flight reads a full party and passes";
        input = (fun () -> shown (preflight ~back:Result.ok ~verdict:Result.ok));
        expectation = full_party_pass;
      };
      {
        name =
          "the return to the save fails: that step failed, the rest pending";
        input =
          (fun () ->
            shown (preflight ~back:(fun () -> not_back) ~verdict:Result.ok));
        expectation =
          String.concat "\n"
            [
              plan_line [ p; p; p; p; p ];
              "run preflight mg-01=current";
              plan_line [ c; p; p; p; p ];
              plan_line [ "failed(not_back: no start state)"; p; p; p; p ];
              "run preflight mg-01=failed";
            ];
      };
      {
        name = "the verdict is a mismatch";
        input =
          (fun () ->
            last 2
              (shown
                 (preflight ~back:Result.ok ~verdict:(fun () ->
                      Error
                        (Story.Failure.cause "mismatch"
                           "the save does not hold what it needs")))));
        expectation =
          plan_line
            [
              d;
              d;
              d;
              d;
              "failed(mismatch: the save does not hold what it needs)";
            ]
          ^ "\nrun preflight mg-01=failed";
      };
    ]
