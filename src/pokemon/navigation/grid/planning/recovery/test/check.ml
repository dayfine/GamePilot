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
