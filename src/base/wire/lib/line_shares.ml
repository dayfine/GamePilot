open Json_fields

type json = Yojson.Safe.t
type op = Greater | Greater_equal | Less | Less_equal
type comparison = { weights : int * int * int; op : op; value : int }
type test = comparison list

let greater ~r ~g ~b value = { weights = (r, g, b); op = Greater; value }
let at_least ~r ~g ~b value = { weights = (r, g, b); op = Greater_equal; value }

let holds { weights = wr, wg, wb; op; value } (r, g, b) =
  let sum = (wr * r) + (wg * g) + (wb * b) in
  match op with
  | Greater -> sum > value
  | Greater_equal -> sum >= value
  | Less -> sum < value
  | Less_equal -> sum <= value

let passes test pixel = List.for_all (fun c -> holds c pixel) test

let op_of_string what = function
  | ">" -> Greater
  | ">=" -> Greater_equal
  | "<" -> Less
  | "<=" -> Less_equal
  | s -> fail "%s: unknown op %S" what s

let string_of_op = function
  | Greater -> ">"
  | Greater_equal -> ">="
  | Less -> "<"
  | Less_equal -> "<="

let comparison_of_json what j =
  let weights =
    match
      List.map (to_int (what ^ ".weights")) (list_field what "weights" j)
    with
    | [ r; g; b ] -> (r, g, b)
    | _ -> fail "%s.weights: expected [r, g, b]" what
  in
  {
    weights;
    op = op_of_string (what ^ ".op") (string_field what "op" j);
    value = int_field what "value" j;
  }

let test_of_json what j = List.map (comparison_of_json what) (to_list what j)

let json_of_comparison { weights = r, g, b; op; value } =
  `Assoc
    [
      ("weights", `List [ `Int r; `Int g; `Int b ]);
      ("op", `String (string_of_op op));
      ("value", `Int value);
    ]

let json_of_test test = `List (List.map json_of_comparison test)

type t = { rows : float list; columns : float list }

let kind = "core.line_shares@1"

let of_json what j =
  let numbers name =
    List.map (to_float (what ^ "." ^ name)) (list_field what name j)
  in
  { rows = numbers "rows"; columns = numbers "columns" }

let floats l = `List (List.map (fun f -> `Float f) l)

let to_json { rows; columns } =
  `Assoc
    [
      ("kind", `String kind); ("rows", floats rows); ("columns", floats columns);
    ]
