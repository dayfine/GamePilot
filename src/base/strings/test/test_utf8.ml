(* Utf8.chars and Utf8.uchars on ASCII, multi-byte characters and a bad byte. *)

let case name input expectation = { Table_test.name; input; expectation }

let codes s () =
  String.concat " "
    (List.map
       (fun u -> Printf.sprintf "U+%04X" (Uchar.to_int u))
       (Strings.Utf8.uchars s))

let pieces s () = String.concat "|" (Strings.Utf8.chars s)

let cases =
  [
    case "ASCII is one character a byte" (pieces "AB.") "A|B|.";
    case "multi-byte characters stay whole" (pieces "…“♀") "…|“|♀";
    case "the empty string has none" (pieces "") "";
    case "code points" (codes "A♂") "U+0041 U+2642";
    case "a bad byte is one replacement character" (codes "\xffA")
      "U+FFFD U+0041";
  ]

let () = Table_test.run "utf8" cases
