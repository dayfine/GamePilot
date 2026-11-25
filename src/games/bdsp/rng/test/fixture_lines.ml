(* Reads the golden vectors written by golden/generate_golden.cpp: one record
   per line, "<op> <inputs...> : <outputs>", where indented lines continue the
   record above. A test recomputes each record's outputs from its inputs and
   prints them the same way; the suite passes when every record matches. *)

type record = { op : string; inputs : string list; expected : string }

let separator = " : "
let continuation = "  "

let split_record line =
  match String.index_opt line ':' with
  | Some at when at > 0 ->
      let head = String.sub line 0 (at - 1) in
      let tail_start = at + String.length separator - 1 in
      let expected =
        String.sub line tail_start (String.length line - tail_start)
      in
      (head, expected)
  | _ -> failwith ("fixture line without \" : \": " ^ line)

let to_record line =
  let head, expected = split_record line in
  match String.split_on_char ' ' head with
  | op :: inputs -> { op; inputs; expected }
  | [] -> failwith ("empty fixture line: " ^ line)

let continue_record records line =
  match records with
  | last :: rest -> { last with expected = last.expected ^ "\n" ^ line } :: rest
  | [] -> failwith ("continuation before any record: " ^ line)

let read path =
  In_channel.with_open_bin path In_channel.input_all
  |> String.split_on_char '\n'
  |> List.filter (fun line -> line <> "")
  |> List.fold_left
       (fun records line ->
         if String.starts_with ~prefix:continuation line then
           continue_record records line
         else to_record line :: records)
       []
  |> List.rev

let hex text = int_of_string ("0x" ^ text)
let hex32 = Printf.sprintf "%08x"

(* Same text as C's "%.17g", which round-trips a double. The Windows C
   runtime writes the exponent with at least three digits ("1e-006"); the
   golden vectors, like C99, use two ("1e-06"), so a leading zero of a
   three-digit exponent is dropped. *)
let float17 x =
  let text = Printf.sprintf "%.17g" x in
  match String.index_opt text 'e' with
  | Some at when String.length text - at = 5 && text.[at + 2] = '0' ->
      String.sub text 0 (at + 2) ^ String.sub text (at + 3) 2
  | _ -> text

(* Checks every record of [op] with [compute], reporting the count and the first
   mismatch as one case. *)
let check_op records op compute =
  let mine = List.filter (fun r -> r.op = op) records in
  let mismatch r =
    let actual = compute r.inputs in
    if actual = r.expected then None
    else
      Some
        (Printf.sprintf "%s %s\nexpected: %s\ngot:      %s" op
           (String.concat " " r.inputs)
           r.expected actual)
  in
  let name = Printf.sprintf "%s (%d records)" op (List.length mine) in
  let result =
    if mine = [] then Error "no records in the fixture"
    else
      match List.find_map mismatch mine with
      | Some why -> Error why
      | None -> Ok ()
  in
  Table_test.report name result
