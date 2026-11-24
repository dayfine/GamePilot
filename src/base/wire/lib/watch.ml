open Json_fields

type json = Yojson.Safe.t
type event_state = Pending | Current | Done | Failed | Skipped
type plan_event = { id : string; state : event_state; detail : string }
type plan = { checkpoint : string; events : plan_event list }

let states =
  [
    ("pending", Pending);
    ("current", Current);
    ("done", Done);
    ("failed", Failed);
    ("skipped", Skipped);
  ]

let state_of_string what s =
  match List.assoc_opt s states with
  | Some state -> state
  | None -> fail "%s.state: unknown state %S" what s

let string_of_state state = fst (List.find (fun (_, st) -> st = state) states)
let what = "watch.plan.params"

let event_of_json j =
  let what = what ^ ".events" in
  {
    id = string_field what "id" j;
    state = state_of_string what (string_field what "state" j);
    detail = string_field what "detail" j;
  }

let json_of_event { id; state; detail } =
  `Assoc
    [
      ("id", `String id);
      ("state", `String (string_of_state state));
      ("detail", `String detail);
    ]

let plan_of_json j =
  {
    checkpoint = string_field what "checkpoint" j;
    events = List.map event_of_json (list_field what "events" j);
  }

let json_of_plan { checkpoint; events } =
  `Assoc
    [
      ("checkpoint", `String checkpoint);
      ("events", `List (List.map json_of_event events));
    ]

let line_of_json j = string_field "watch.log.params" "line" j
let json_of_line line = `Assoc [ ("line", `String line) ]
let reason_of_json j = string_field "stop.params" "reason" j
let json_of_reason reason = `Assoc [ ("reason", `String reason) ]
