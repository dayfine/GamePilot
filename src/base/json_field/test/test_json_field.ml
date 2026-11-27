(* Json_field: typed JSON object readers and field-path error messages tested
   directly on in-memory Yojson.Safe.t values (no external mocks or files). *)

let where = "test.json: "
let parse s = Yojson.Safe.from_string s

let run f () =
  match Json_field.catch f with Ok s -> "ok:" ^ s | Error e -> "err:" ^ e

let obj s = Json_field.as_object "test.json" (parse s)
let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "json_field"
    [
      case "as_object rejects non-object"
        (run (fun () ->
             ignore (Json_field.as_object "root" (parse "42"));
             ""))
        "err:root is not a JSON object.";
      case "int reads integer field"
        (run (fun () ->
             string_of_int (Json_field.int ~where "x" (obj {|{"x": 7}|}))))
        "ok:7";
      case "int rejects missing field"
        (run (fun () -> string_of_int (Json_field.int ~where "x" (obj {|{}|}))))
        "err:test.json: x is missing.";
      case "int rejects wrong type"
        (run (fun () ->
             string_of_int (Json_field.int ~where "x" (obj {|{"x": "7"}|}))))
        "err:test.json: x is not an integer.";
      case "string reads string field"
        (run (fun () ->
             Json_field.string ~where "name" (obj {|{"name": "ok"}|})))
        "ok:ok";
      case "string_opt returns None when omitted"
        (run (fun () ->
             Option.value ~default:"none"
               (Json_field.string_opt ~where "name" (obj {|{}|}))))
        "ok:none";
      case "bool_or uses default when omitted"
        (run (fun () ->
             string_of_bool
               (Json_field.bool_or ~where ~default:true "flag" (obj {|{}|}))))
        "ok:true";
      case "bool_or rejects non-boolean"
        (run (fun () ->
             string_of_bool
               (Json_field.bool_or ~where ~default:false "flag"
                  (obj {|{"flag": 1}|}))))
        "err:test.json: flag is not true or false.";
      case "records passes indexed prefix to item reader"
        (run (fun () ->
             let xs =
               Json_field.records ~where "items"
                 (obj {|{"items": [{"n": 1}, {"n": "bad"}]}|}) (fun ~where o ->
                   Json_field.int ~where "n" o)
             in
             string_of_int (List.length xs)))
        "err:test.json: items[1].n is not an integer.";
      case "strings reads string list"
        (run (fun () ->
             String.concat "," (Json_field.strings "tags" (parse {|["a","b"]|}))))
        "ok:a,b";
      case "strings rejects non-string element"
        (run (fun () ->
             String.concat "," (Json_field.strings "tags" (parse {|["a", 2]|}))))
        "err:tags[1] is not a string.";
    ]
