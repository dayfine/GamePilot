open Json_fields

type json = Yojson.Safe.t
type button = A | B | Select | Start | Right | Left | Up | Down | R | L

let all_buttons = [ A; B; Select; Start; Right; Left; Up; Down; R; L ]

let string_of_button = function
  | A -> "A"
  | B -> "B"
  | Select -> "Select"
  | Start -> "Start"
  | Right -> "Right"
  | Left -> "Left"
  | Up -> "Up"
  | Down -> "Down"
  | R -> "R"
  | L -> "L"

let button_of_string s =
  List.find_opt (fun b -> string_of_button b = s) all_buttons

type command =
  | Press of { buttons : button list; hold_ms : int; cooldown_ms : int }
  | Wait of { wait_ms : int }

let pressed_button v =
  let s = to_string "command.press" v in
  match button_of_string s with
  | Some b -> b
  | None -> fail "command.press: unknown button %S" s

let press_of_json press j =
  Press
    {
      buttons = List.map pressed_button (to_list "command.press" press);
      hold_ms = int_field "command" "hold_ms" j;
      cooldown_ms = int_field "command" "cooldown_ms" j;
    }

let command_of_json j =
  match field_opt "command" "press" j with
  | Some press -> press_of_json press j
  | None -> Wait { wait_ms = int_field "command" "wait_ms" j }

let json_of_buttons buttons =
  json_of_strings (List.map string_of_button buttons)

let json_of_press buttons ~hold_ms ~cooldown_ms =
  `Assoc
    [
      ("press", json_of_buttons buttons);
      ("hold_ms", `Int hold_ms);
      ("cooldown_ms", `Int cooldown_ms);
    ]

let json_of_command = function
  | Press { buttons; hold_ms; cooldown_ms } ->
      json_of_press buttons ~hold_ms ~cooldown_ms
  | Wait { wait_ms } -> `Assoc [ ("wait_ms", `Int wait_ms) ]

type batch_done = { batch_id : string; seq : int; t_ms : float }

let batch_done_of_json j : batch_done =
  let what = "batch_done" in
  {
    batch_id = string_field what "batch_id" j;
    seq = int_field what "seq" j;
    t_ms = float_field what "t_ms" j;
  }

let json_of_batch_done ({ batch_id; seq; t_ms } : batch_done) =
  `Assoc
    [ ("batch_id", `String batch_id); ("seq", `Int seq); ("t_ms", `Float t_ms) ]

type submit_result = { batch_id : string; start_seq : int }

let submit_result_of_json j =
  let what = "submit.result" in
  {
    batch_id = string_field what "batch_id" j;
    start_seq = int_field what "start_seq" j;
  }

let json_of_submit_result ({ batch_id; start_seq } : submit_result) =
  `Assoc [ ("batch_id", `String batch_id); ("start_seq", `Int start_seq) ]

let cancel_result_of_json j = int_field "cancel.result" "released_seq" j
let json_of_cancel_result seq = `Assoc [ ("released_seq", `Int seq) ]
