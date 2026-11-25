(* The "did you mean" of an unknown name: the nearest known names, or none. *)

let unknown name () =
  Name_suggestion.unknown ~what:"place" name
    [ "dept_store_4f_clerk"; "dept_store_1f_save"; "lavender_nurse" ]

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "name_suggestion"
    [
      case "edit distance"
        (fun () -> string_of_int (Name_suggestion.distance "kitten" "sitting"))
        "3";
      case "one letter off"
        (unknown "dept_store_4f_clrk")
        "no place \"dept_store_4f_clrk\"; did you mean dept_store_4f_clerk?";
      case "two equally near"
        (fun () ->
          String.concat "," (Name_suggestion.closest "ab" [ "aa"; "bb"; "zz" ]))
        "aa,bb";
      case "nothing near" (unknown "pallet_house") "no place \"pallet_house\"";
    ]
