(* Checks for the planner tests' cases, reported with Case_table.report. *)

(* Ok when [holds], else an error saying what was [expected] and what the
   plan was. *)
let expect ~expected ~plan holds =
  if holds then Ok ()
  else Error (Printf.sprintf "expected %s; planned: %s" expected plan)

(* Ok when [read] is [expected], both as text. *)
let equal ~expected read =
  if read = expected then Ok ()
  else Error (Printf.sprintf "expected %S, read %S" expected read)
