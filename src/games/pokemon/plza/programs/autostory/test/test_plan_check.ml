(* Plan_check over every plan in plans/, and on plans with a bad key: an
   unknown execution key, a signature field or minimap the readers do not
   know, an unknown skip_if flag. *)

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

(* 03.04's plan, its execution or its events' skip_if replaced. *)
let base () =
  Yojson.Safe.from_file (Filename.concat plans_dir "03.04.plan.json")

let with_execution fields =
  match base () with
  | `Assoc top ->
      `Assoc
        (List.map
           (fun (k, v) ->
             if k = "execution" then (k, `Assoc fields) else (k, v))
           top)
  | other -> other

let rec with_skip_if flag = function
  | `Assoc fields ->
      `Assoc
        (List.map
           (fun (k, v) ->
             if k = "skip_if" then (k, `List [ `String flag ])
             else (k, with_skip_if flag v))
           fields)
  | `List items -> `List (List.map (with_skip_if flag) items)
  | other -> other

let case name json expectation : Table_test.case =
  { name; input = (fun () -> checked (json ())); expectation }

let bad_cases =
  [
    case "a key the runner does not read"
      (fun () -> with_execution [ ("save", `String "autosave") ])
      "03.04: unknown execution key \"save\"";
    case "reload_when_chained not a boolean"
      (fun () -> with_execution [ ("reload_when_chained", `String "yes") ])
      "03.04: execution.reload_when_chained is not a boolean";
    case "a start signature with an unknown field"
      (fun () ->
        with_execution [ ("start_signature", `Assoc [ ("hp", `Int 1) ]) ])
      "start_signature_unread: 03.04: its start signature has \"hp\": its \
       fields are talk_prompt, wild_zone and near_rocks (true or false), party \
       (a count) and minimap (a recorded name)";
    case "an end signature naming an unrecorded minimap"
      (fun () ->
        with_execution
          [ ("end_signature", `Assoc [ ("minimap", `String "99.99-start") ]) ])
      "start_signature_unread: 03.04: its end signature names minimap \
       99.99-start, which is not recorded";
    case "an unknown skip_if flag"
      (fun () -> with_skip_if "battle_over" (base ()))
      "03.04 event into_pokemon_center: unknown skip_if flag \"battle_over\"";
    case "a skip_if minimap not recorded"
      (fun () -> with_skip_if "minimap:99.99-start" (base ()))
      "03.04 event into_pokemon_center: skip_if \"minimap:99.99-start\": no \
       minimap \"99.99-start\" is recorded";
  ]

let () = Table_test.run "plza plan check" (plan_cases @ bad_cases)
