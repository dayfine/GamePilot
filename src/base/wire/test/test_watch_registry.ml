(* The watch registry entry as the daemon writes it (registry_entry_json in
   daemon/watch/server/watch_registry.cpp) and a run page's /summary.json, as
   [gamepilot runs] reads them. *)

module R = Wire.Watch_registry

let entry_text =
  {|{"pid":4242,"port":47950,"listen":"127.0.0.1","backend":"mgba","run_folder":"/runs/2026-11-23-mg-02-testing-1","checkpoint":"mg-02","started_ms":1795435200000}|}

let decode f text =
  match f (Yojson.Safe.from_string text) with
  | v -> v
  | exception Wire.Decode_error e -> failwith e

let entry () =
  let e = decode R.of_json entry_text in
  Printf.sprintf "%d %d %s %s %s %d" e.pid e.port e.backend e.checkpoint
    (Filename.basename e.run_folder)
    e.started_ms

let summary text =
  let s = decode R.summary_of_json text in
  Printf.sprintf "run %s, plan %s"
    (match s.run with Some r -> r.mode | None -> "none")
    (match s.plan with Some p -> p.checkpoint | None -> "none")

let cases : Table_test.case list =
  [
    {
      name = "an entry as the daemon writes it";
      input = entry;
      expectation =
        "4242 47950 mgba mg-02 2026-11-23-mg-02-testing-1 1795435200000";
    };
    {
      name = "an entry without a pid is not one";
      input =
        (fun () ->
          match decode R.of_json {|{"port":1}|} with
          | _ -> "decoded"
          | exception Failure _ -> "rejected");
      expectation = "rejected";
    };
    {
      name = "summary: nothing sent yet";
      input = (fun () -> summary {|{"run":null,"plan":null}|});
      expectation = "run none, plan none";
    };
    {
      name = "summary: a plan with times, no chain";
      input =
        (fun () ->
          summary
            {|{"run":null,"plan":{"checkpoint":"mg-01","events":[{"id":"a","state":"current","detail":"","started_ms":5}]}}|});
      expectation = "run none, plan mg-01";
    };
  ]

let () = Table_test.run "watch_registry" cases
