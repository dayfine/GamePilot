(* Plan_check over every plan in plans/, and on plans with a bad key: an
   unknown execution key, a signature field or minimap the readers do not
   know, an unknown skip_if or end flag. *)

open Plza_engine

let plans_dir = "../plans"

let checked json =
  match Plan_decode.decode ~source:"case" json with
  | Error e -> "does not decode: " ^ e
  | Ok plan -> (
      match Plza_autostory.Plan_check.check plan with
      | Ok () -> "ok"
      | Error e -> e)

let plan_cases =
  Sys.readdir plans_dir |> Array.to_list
  |> List.filter (String.ends_with ~suffix:".plan.json")
  |> List.sort compare
  |> List.map (fun file : Table_test.case ->
         {
           name = file;
           input =
             (fun () ->
               checked (Yojson.Safe.from_file (Filename.concat plans_dir file)));
           expectation = "ok";
         })

(* 03.07's plan (03.03's for a skip_if, which 03.07's events no longer
   carry), its execution, its events' skip_if or its end replaced. *)
let base ?(file = "03.07-pokemon-center.plan.json") () =
  Yojson.Safe.from_file (Filename.concat plans_dir file)

let with_execution fields =
  match base () with
  | `Assoc top ->
      `Assoc
        (List.map
           (fun (k, v) ->
             if k = "execution" then (k, `Assoc fields) else (k, v))
           top)
  | other -> other

(* Every [key] list in the plan, as [[flag]]. *)
let rec with_list key flag = function
  | `Assoc fields ->
      `Assoc
        (List.map
           (fun (k, v) ->
             if k = key then (k, `List [ `String flag ])
             else (k, with_list key flag v))
           fields)
  | `List items -> `List (List.map (with_list key flag) items)
  | other -> other

let with_skip_if flag =
  with_list "skip_if" flag (base ~file:"03.03-battle-taunie.plan.json" ())

let with_end flag = with_list "is" flag (base ())

let case name json expectation : Table_test.case =
  { name; input = (fun () -> checked (json ())); expectation }

let bad_cases =
  [
    case "a key the runner does not read"
      (fun () -> with_execution [ ("save", `String "autosave") ])
      "03.07-pokemon-center: unknown execution key \"save\"";
    case "reload_when_chained not a boolean"
      (fun () -> with_execution [ ("reload_when_chained", `String "yes") ])
      "03.07-pokemon-center: execution.reload_when_chained is not a boolean";
    case "a start signature with an unknown field"
      (fun () ->
        with_execution [ ("start_signature", `Assoc [ ("hp", `Int 1) ]) ])
      "start_signature_unread: 03.07-pokemon-center: its start signature has \
       \"hp\": its fields are talk_prompt, wild_zone and near_rocks (true or \
       false), party (a count) and minimap (a recorded name)";
    case "an end signature naming an unrecorded minimap"
      (fun () ->
        with_execution
          [ ("end_signature", `Assoc [ ("minimap", `String "nowhere") ]) ])
      "start_signature_unread: 03.07-pokemon-center: its end signature names \
       minimap nowhere, which is not recorded";
    case "an unknown skip_if flag"
      (fun () -> with_skip_if "battle_over")
      "03.03-battle-taunie event after_taunie_battle: unknown flag \
       \"battle_over\"";
    case "a skip_if minimap not recorded"
      (fun () -> with_skip_if "minimap:nowhere")
      "03.03-battle-taunie event after_taunie_battle: \"minimap:nowhere\": no \
       minimap \"nowhere\" is recorded";
    case "an unknown end flag"
      (fun () -> with_end "battle_over")
      "03.07-pokemon-center end: unknown flag \"battle_over\"";
    case "an end minimap not recorded"
      (fun () -> with_end "minimap:nowhere")
      "03.07-pokemon-center end: \"minimap:nowhere\": no minimap \"nowhere\" \
       is recorded";
  ]

let () = Table_test.run "plza plan check" (plan_cases @ bad_cases)
