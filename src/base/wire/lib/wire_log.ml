open Json_fields

type json = Yojson.Safe.t
type direction = In | Out
type log_line = { dir : direction; t_ms : float; msg : Jsonrpc.message }

let direction_of_string = function
  | "in" -> In
  | "out" -> Out
  | s -> fail "wire log line: dir %S is neither in nor out" s

let string_of_direction = function In -> "in" | Out -> "out"

let log_line_of_json j =
  let what = "wire log line" in
  {
    dir = direction_of_string (string_field what "dir" j);
    t_ms = float_field what "t_ms" j;
    msg = Jsonrpc.message_of_json (field what "msg" j);
  }

let json_of_log_line { dir; t_ms; msg } =
  `Assoc
    [
      ("dir", `String (string_of_direction dir));
      ("t_ms", `Float t_ms);
      ("msg", Jsonrpc.json_of_message msg);
    ]
