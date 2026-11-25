(* Run_attempts over scripted attempts: which attempts reload first, and how
   the run ends. *)

module A = Plza_autostory.Run_attempts

let off_start =
  A.Failed
    {
      at = "start";
      reason = "chain_off_start: the run is not at 03.08's start";
      repeats = true;
      off_start = true;
    }

let short =
  A.Failed
    {
      at = "#1 catch_more_species";
      reason = "short_of_species: the party holds 3 species of 4";
      repeats = false;
      off_start = false;
    }

(* The attempts [script] gives in turn (then passes), each logged with whether
   it began with a reload, and the run's end. *)
let attempts ?(has_start = true) ?(retries = 0) ?(reload_first = false) script
    () =
  let left = ref script in
  let lines = ref [] in
  let attempt ~attempt ~reload =
    lines :=
      Printf.sprintf "attempt %d%s" attempt
        (if reload then " after a reload" else "")
      :: !lines;
    match !left with
    | o :: rest ->
        left := rest;
        o
    | [] -> A.Passed
  in
  let log line = lines := line :: !lines in
  let ended =
    match A.run ~has_start ~retries ~reload_first ~log attempt with
    | A.Passed -> "passed"
    | A.Failed f ->
        Printf.sprintf "failed at %s: %s; repeats %b" f.at f.reason f.repeats
  in
  String.concat "\n" (List.rev (ended :: !lines))

let case name input expectation : Table_test.case = { name; input; expectation }

let cases =
  [
    case "off its start on the first run: one reload, then it passes"
      (attempts [ off_start ])
      "attempt 1\n\
       off its start (chain_off_start: the run is not at 03.08's start): back \
       to the latest autosave, and its start checked again\n\
       attempt 2 after a reload\n\
       passed";
    case "off its start again after the reload: fails, and repeats"
      (attempts [ off_start; off_start ])
      "attempt 1\n\
       off its start (chain_off_start: the run is not at 03.08's start): back \
       to the latest autosave, and its start checked again\n\
       attempt 2 after a reload\n\
       failed at start: off its start after a reload: chain_off_start: the run \
       is not at 03.08's start; repeats true";
    case "off its start on a run that began with a reload: no second reload"
      (attempts ~reload_first:true [ off_start ])
      "attempt 1 after a reload\n\
       failed at start: off its start after a reload: chain_off_start: the run \
       is not at 03.08's start; repeats true";
    case "off its start with no start to go back to (01.00b): fails at once"
      (attempts ~has_start:false [ off_start ])
      "attempt 1\n\
       failed at start: chain_off_start: the run is not at 03.08's start; \
       repeats true";
    case "short of species, no retries: fails, a failure that does not repeat"
      (attempts [ short ])
      "attempt 1\n\
       failed at #1 catch_more_species: short_of_species: the party holds 3 \
       species of 4; repeats false";
    case "short of species once, retries 2: a reload, then it passes"
      (attempts ~retries:2 [ short ])
      "attempt 1\n\
       a failure a reload may fix: trying again\n\
       attempt 2 after a reload\n\
       passed";
    case "short of species three times, retries 2: fails after 3 attempts"
      (attempts ~retries:2 [ short; short; short ])
      "attempt 1\n\
       a failure a reload may fix: trying again\n\
       attempt 2 after a reload\n\
       a failure a reload may fix: trying again\n\
       attempt 3 after a reload\n\
       failed at #1 catch_more_species: failed the same way on all 3 attempts: \
       short_of_species: the party holds 3 species of 4; repeats true";
    case "off its start, then short twice, retries 2: the reload is not a retry"
      (attempts ~retries:2 [ off_start; short; short ])
      "attempt 1\n\
       off its start (chain_off_start: the run is not at 03.08's start): back \
       to the latest autosave, and its start checked again\n\
       attempt 2 after a reload\n\
       a failure a reload may fix: trying again\n\
       attempt 3 after a reload\n\
       a failure a reload may fix: trying again\n\
       attempt 4 after a reload\n\
       passed";
    case "a failure that repeats, retries 2: fails at once"
      (attempts ~retries:2
         [
           A.Failed
             {
               at = "#1 catch_more_species";
               reason = "walk_stick: no stick";
               repeats = true;
               off_start = false;
             };
         ])
      "attempt 1\n\
       failed at #1 catch_more_species: walk_stick: no stick; repeats true";
    case "retries with no start to go back to: no reload"
      (attempts ~has_start:false ~retries:2 [ short ])
      "attempt 1\n\
       failed at #1 catch_more_species: short_of_species: the party holds 3 \
       species of 4; repeats false";
    case "an action's own start check is off its start; a catch is not"
      (fun () ->
        Printf.sprintf "%b %b %b"
          (A.off_start (Engine_run.Failure.cause "rocks_not_left" ""))
          (A.off_start
             (Engine_run.Failure.cause ~repeats:true "chain_off_start" ""))
          (A.off_start (Engine_run.Failure.cause "short_of_species" "")))
      "true true false";
  ]

let () = Table_test.run "plza run attempts" cases
