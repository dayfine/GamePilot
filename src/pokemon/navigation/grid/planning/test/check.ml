(* Runs named cases and reports each; [finish] fails the test if any failed. *)

let failed = ref 0

let report name = function
  | Ok () -> Printf.printf "ok %s\n%!" name
  | Error why ->
      incr failed;
      Printf.printf "FAILED %s: %s\n%!" name why

let finish () =
  if !failed > 0 then (
    Printf.printf "%d failed\n" !failed;
    exit 1)

(* Ok when [holds], else an error saying what was [expected] and what the
   plan was. *)
let expect ~expected ~plan holds =
  if holds then Ok ()
  else Error (Printf.sprintf "expected %s; planned: %s" expected plan)

(* Ok when [read] is [expected], both as text. *)
let equal ~expected read =
  if read = expected then Ok ()
  else Error (Printf.sprintf "expected %S, read %S" expected read)
