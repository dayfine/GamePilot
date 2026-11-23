type case = { name : string; input : unit -> string; expectation : string }

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

let run suite cases =
  let run_one { name; input; expectation } =
    let actual = input () in
    if actual = expectation then Printf.printf "ok %s - %s\n%!" suite name
    else (
      incr failed;
      Printf.printf "FAILED %s - %s:\nexpected:\n%s\ngot:\n%s\n%!" suite name
        expectation actual)
  in
  List.iter run_one cases;
  finish ()
