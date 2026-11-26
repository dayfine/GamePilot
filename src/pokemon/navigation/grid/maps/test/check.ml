(* Checks for the map tests' cases, reported with Table_test.report. *)

(* Ok when [read] is [expected], both as text. *)
let equal what ~expected read =
  if read = expected then Ok ()
  else Error (Printf.sprintf "%s: expected %S, read %S" what expected read)

(* The first error of the checks, run in order. *)
let all checks =
  List.fold_left (fun result check -> Result.bind result check) (Ok ()) checks

(* Ok when [message] names every one of [parts]. *)
let mentions message parts =
  match
    List.find_opt (fun part -> not (Substring.contains message part)) parts
  with
  | None -> Ok ()
  | Some part ->
      Error (Printf.sprintf "expected an error naming %S, got %S" part message)

(* [base] with the first [find] replaced by [replacement]; fails the test
   when [find] is not in it, as the case would test nothing. *)
let edited base find replacement =
  let n = String.length find in
  match Substring.find base find with
  | None -> failwith ("not in the map: " ^ find)
  | Some i ->
      String.sub base 0 i ^ replacement
      ^ String.sub base (i + n) (String.length base - i - n)
