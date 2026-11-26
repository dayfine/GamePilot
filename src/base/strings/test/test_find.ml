(* Where one piece of text first occurs inside another, from a given place. *)

let find ?from text part () =
  match Strings.Find.substring ?from text part with
  | Some i -> string_of_int i
  | None -> "none"

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "find"
    [
      case "the first of two" (find "on/on" "on") "0";
      case "from past the first" (find ~from:1 "on/on" "on") "3";
      case "from at a match" (find ~from:3 "on/on" "on") "3";
      case "from past the last" (find ~from:4 "on/on" "on") "none";
      case "absent" (find "lock-on" "zl") "none";
      case "longer than the text" (find "on" "lock-on") "none";
      case "the empty part" (find ~from:2 "on" "") "2";
      case "the empty part past the end" (find ~from:3 "on" "") "none";
    ]
