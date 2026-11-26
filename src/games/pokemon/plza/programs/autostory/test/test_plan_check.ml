(* Plan_check over every plan in plans/, and on a plan with an unknown
   skip_if flag. *)

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

(* 01.03's plan, its events' skip_if replaced. *)
let base () =
  Yojson.Safe.from_file (Filename.concat plans_dir "01.03.plan.json")

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
    case "an unknown skip_if flag"
      (fun () -> with_skip_if "battle_over" (base ()))
      "01.03 event approach_starter: unknown skip_if flag \"battle_over\"";
  ]

let () = Table_test.run "plza plan check" (plan_cases @ bad_cases)
