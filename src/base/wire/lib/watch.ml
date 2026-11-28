open Json_fields

type json = Yojson.Safe.t
type event_state = Pending | Current | Done | Failed | Skipped

type plan_event = {
  id : string;
  state : event_state;
  detail : string;
  started_ms : int option;
  ended_ms : int option;
}

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
let int_opt what name j = Option.map (to_int what) (field_opt what name j)

let event_of_json j =
  let what = what ^ ".events" in
  {
    id = string_field what "id" j;
    state = state_of_string what (string_field what "state" j);
    detail = string_field what "detail" j;
    started_ms = int_opt what "started_ms" j;
    ended_ms = int_opt what "ended_ms" j;
  }

(* The times only once they are known. *)
let json_of_event { id; state; detail; started_ms; ended_ms } =
  let time name = Option.map (fun ms -> (name, `Int ms)) in
  `Assoc
    ([
       ("id", `String id);
       ("state", `String (string_of_state state));
       ("detail", `String detail);
     ]
    @ List.filter_map Fun.id
        [ time "started_ms" started_ms; time "ended_ms" ended_ms ])

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

let pending id =
  { id; state = Pending; detail = ""; started_ms = None; ended_ms = None }

let stamp ~now_ms e state detail =
  let e = { e with state; detail } in
  match state with
  | Pending -> { e with started_ms = None; ended_ms = None }
  | Current -> { e with started_ms = Some now_ms; ended_ms = None }
  | Done | Failed | Skipped ->
      {
        e with
        started_ms = Some (Option.value e.started_ms ~default:now_ms);
        ended_ms = Some now_ms;
      }

let event_ms ~now_ms e =
  match (e.started_ms, e.ended_ms, e.state, now_ms) with
  | Some start, Some stop, _, _ -> Some (stop - start)
  | Some start, None, Current, Some now -> Some (now - start)
  | _ -> None

let plan_ms ~now_ms plan =
  let starts = List.filter_map (fun e -> e.started_ms) plan.events in
  let ends = List.filter_map (fun e -> e.ended_ms) plan.events in
  let running =
    List.exists (fun e -> e.state = Current && e.ended_ms = None) plan.events
  in
  let last = function [] -> None | l -> Some (List.fold_left max min_int l) in
  let stop = if running && now_ms <> None then now_ms else last ends in
  match (starts, stop) with
  | [], _ | _, None -> None
  | _, Some stop -> Some (stop - List.fold_left min max_int starts)

type counter = { label : string; value : string; until_ms : int option }

let counter ?until_ms label value = { label; value; until_ms }

let counter_of_json j =
  let what = "watch.counters.params.items" in
  {
    label = string_field what "label" j;
    value = string_field what "value" j;
    until_ms = int_opt what "until_ms" j;
  }

let json_of_counter { label; value; until_ms } =
  let fields = [ ("label", `String label); ("value", `String value) ] in
  let extra =
    match until_ms with None -> [] | Some ms -> [ ("until_ms", `Int ms) ]
  in
  `Assoc (fields @ extra)

let counters_of_json j =
  List.map counter_of_json (list_field "watch.counters.params" "items" j)

let json_of_counters items =
  `Assoc [ ("items", `List (List.map json_of_counter items)) ]

let line_of_json j = string_field "watch.log.params" "line" j
let json_of_line line = `Assoc [ ("line", `String line) ]
let reason_of_json j = string_field "stop.params" "reason" j
let json_of_reason reason = `Assoc [ ("reason", `String reason) ]
