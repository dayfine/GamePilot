(* One piece of text inside another: anywhere, at either end, or not at all,
   and where it first occurs. *)

let contains text part () = string_of_bool (Substring.contains text part)

let find ?from text part () =
  match Substring.find ?from text part with
  | Some i -> string_of_int i
  | None -> "none"

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "substring"
    [
      case "in the middle" (contains "lock-on 1/5 tried" "1/5") "true";
      case "at the start" (contains "lock-on" "lock") "true";
      case "at the end" (contains "lock-on" "on") "true";
      case "the whole text" (contains "lock-on" "lock-on") "true";
      case "absent" (contains "lock-on" "zl") "false";
      case "longer than the text" (contains "on" "lock-on") "false";
      case "the empty part" (contains "lock-on" "") "true";
      case "in the empty text" (contains "" "a") "false";
      case "find: the first of two" (find "on/on" "on") "0";
      case "find: from past the first" (find ~from:1 "on/on" "on") "3";
      case "find: from at a match" (find ~from:3 "on/on" "on") "3";
      case "find: from past the last" (find ~from:4 "on/on" "on") "none";
      case "find: absent" (find "lock-on" "zl") "none";
      case "find: the empty part" (find ~from:2 "on" "") "2";
      case "find: the empty part past the end" (find ~from:3 "on" "") "none";
    ]
