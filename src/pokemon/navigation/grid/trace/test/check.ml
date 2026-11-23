(* Runs named cases whose result is text, and fails the test if any case's
   text is not the expected one. *)

type case = { name : string; input : unit -> string; expectation : string }

let run suite cases =
  let failed =
    List.filter
      (fun { name; input; expectation } ->
        let actual = input () in
        if actual = expectation then (
          Printf.printf "ok %s - %s\n%!" suite name;
          false)
        else (
          Printf.printf "FAILED %s - %s:\nexpected:\n%s\ngot:\n%s\n%!" suite
            name expectation actual;
          true))
      cases
  in
  if failed <> [] then (
    Printf.printf "%d failed\n" (List.length failed);
    exit 1)
