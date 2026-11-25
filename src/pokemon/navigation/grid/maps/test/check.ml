(* Checks for the map tests' cases, reported with Table_test.report. *)

(* Ok when [read] is [expected], both as text. *)
let equal what ~expected read =
  if read = expected then Ok ()
  else Error (Printf.sprintf "%s: expected %S, read %S" what expected read)

(* The first error of the checks, run in order. *)
let all checks =
  List.fold_left (fun result check -> Result.bind result check) (Ok ()) checks

let contains text part =
  let n = String.length part in
  let rec at i =
    i + n <= String.length text && (String.sub text i n = part || at (i + 1))
  in
  at 0

(* Ok when [message] names every one of [parts]. *)
let mentions message parts =
  match List.find_opt (fun part -> not (contains message part)) parts with
  | None -> Ok ()
  | Some part ->
      Error (Printf.sprintf "expected an error naming %S, got %S" part message)

(* [base] with the first [find] replaced by [replacement]; fails the test
   when [find] is not in it, as the case would test nothing. *)
let edited base find replacement =
  let n = String.length find in
  let rec at i =
    if i + n > String.length base then failwith ("not in the map: " ^ find)
    else if String.sub base i n = find then i
    else at (i + 1)
  in
  let i = at 0 in
  String.sub base 0 i ^ replacement
  ^ String.sub base (i + n) (String.length base - i - n)
