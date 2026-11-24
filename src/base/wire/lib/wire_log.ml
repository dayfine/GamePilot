open Json_fields

type json = Yojson.Safe.t
type direction = In | Out | Daemon

type log_line = {
  dir : direction;
  t_ms : float;
  conn : int option;
  owner : string option;
  msg : Jsonrpc.message;
}

let direction_of_string = function
  | "in" -> In
  | "out" -> Out
  | "daemon" -> Daemon
  | s -> fail "wire log line: dir %S is not in, out or daemon" s

let string_of_direction = function
  | In -> "in"
  | Out -> "out"
  | Daemon -> "daemon"

let log_line_of_json j =
  let what = "wire log line" in
  {
    dir = direction_of_string (string_field what "dir" j);
    t_ms = float_field what "t_ms" j;
    conn = Option.map (to_int (what ^ ".conn")) (field_opt what "conn" j);
    owner = Option.map (to_string (what ^ ".owner")) (field_opt what "owner" j);
    msg = Jsonrpc.message_of_json (field what "msg" j);
  }

let optional name f = Option.fold ~none:[] ~some:(fun v -> [ (name, f v) ])

let json_of_log_line { dir; t_ms; conn; owner; msg } =
  `Assoc
    ([ ("dir", `String (string_of_direction dir)); ("t_ms", `Float t_ms) ]
    @ optional "conn" (fun c -> `Int c) conn
    @ optional "owner" (fun o -> `String o) owner
    @ [ ("msg", Jsonrpc.json_of_message msg) ])
