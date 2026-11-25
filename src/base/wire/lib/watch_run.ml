open Json_fields

type json = Yojson.Safe.t
type state = Pending | Current | Passed | Failed | Skipped
type checkpoint = { id : string; state : state; elapsed_ms : int }

type t = {
  mode : string;
  trial : int;
  trials : int;
  passes : int;
  fails : int;
  started_ms : int;
  checkpoints : checkpoint list;
}

let what = "watch.run.params"

let states =
  [
    ("pending", Pending);
    ("current", Current);
    ("passed", Passed);
    ("failed", Failed);
    ("skipped", Skipped);
  ]

let state_of_string s =
  match List.assoc_opt s states with
  | Some state -> state
  | None -> fail "%s.checkpoints.state: unknown state %S" what s

let string_of_state state = fst (List.find (fun (_, st) -> st = state) states)

let checkpoint_of_json j =
  let what = what ^ ".checkpoints" in
  {
    id = string_field what "id" j;
    state = state_of_string (string_field what "state" j);
    elapsed_ms = int_field what "elapsed_ms" j;
  }

let json_of_checkpoint { id; state; elapsed_ms } =
  `Assoc
    [
      ("id", `String id);
      ("state", `String (string_of_state state));
      ("elapsed_ms", `Int elapsed_ms);
    ]

let of_json j =
  {
    mode = string_field what "mode" j;
    trial = int_field what "trial" j;
    trials = int_field what "trials" j;
    passes = int_field what "passes" j;
    fails = int_field what "fails" j;
    started_ms = int_field what "started_ms" j;
    checkpoints = List.map checkpoint_of_json (list_field what "checkpoints" j);
  }

let to_json t =
  `Assoc
    [
      ("mode", `String t.mode);
      ("trial", `Int t.trial);
      ("trials", `Int t.trials);
      ("passes", `Int t.passes);
      ("fails", `Int t.fails);
      ("started_ms", `Int t.started_ms);
      ("checkpoints", `List (List.map json_of_checkpoint t.checkpoints));
    ]
