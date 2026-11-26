(* One piece of text inside another: anywhere, at either end, or not at all. *)

let contains text part () = string_of_bool (Substring.contains text part)
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
    ]
