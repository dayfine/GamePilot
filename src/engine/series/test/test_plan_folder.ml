(* A plan folder's checkpoints in run order, a range of them and the one
   before an id (Engine_series.Plan_folder), over a scratch folder. *)

module F = Engine_series.Plan_folder

let case name input expectation = { Table_test.name; input; expectation }

(* A fresh folder holding [files], empty. *)
let folder files =
  let dir = Filename.temp_dir "plan_folder" "" in
  List.iter
    (fun name -> Out_channel.with_open_bin (Filename.concat dir name) ignore)
    files;
  dir

let ids_text = function Ok ids -> String.concat ", " ids | Error _ -> "error"

let select_text ids ~from_id ~to_id =
  match F.select ids ~from_id ~to_id with
  | Ok (selected, after) ->
      String.concat ", " selected
      ^ " then "
      ^ Option.value after ~default:"none"
  | Error e -> "error: " ^ e

let ids = [ "mg-01"; "mg-04"; "mg-05a"; "mg-05"; "mg-06" ]

(* PLZA's ids: the story's number, then a name; in run order. *)
let plza_ids =
  [
    "03.02-out-of-hotel-z";
    "03.03-battle-taunie";
    "03.10-fourth-species";
    "03.11-fifth-species";
  ]

let () =
  Table_test.run "plan_folder"
    [
      case "plan files only, in run order (split parts first)"
        (fun () ->
          ids_text
            (F.checkpoint_ids
               (folder
                  [
                    "mg-05.plan.json";
                    "mg-05a.plan.json";
                    "mg-01.plan.json";
                    "notes.md";
                    "mg-01.start.ss";
                  ])))
        "mg-01, mg-05a, mg-05";
      case "a folder that is not there is an error"
        (fun () ->
          ids_text (F.checkpoint_ids "/nonexistent/gamepilot-plan-folder"))
        "error";
      case "a range and the id after it"
        (fun () -> select_text ids ~from_id:"mg-04" ~to_id:"mg-05")
        "mg-04, mg-05a, mg-05 then mg-06";
      case "a range to the last id has none after it"
        (fun () -> select_text ids ~from_id:"mg-05" ~to_id:"mg-06")
        "mg-05, mg-06 then none";
      case "an unknown first id"
        (fun () -> select_text ids ~from_id:"mg-02" ~to_id:"mg-05")
        "error: no checkpoint mg-02";
      case "a last id before the first"
        (fun () -> select_text ids ~from_id:"mg-05" ~to_id:"mg-04")
        "error: no checkpoint mg-04 at or after mg-05";
      case "a bound named by its number alone"
        (fun () -> select_text plza_ids ~from_id:"03.02" ~to_id:"03.10")
        "03.02-out-of-hotel-z, 03.03-battle-taunie, 03.10-fourth-species then \
         03.11-fifth-species";
      case "a full id is a bound too"
        (fun () ->
          select_text plza_ids ~from_id:"03.03-battle-taunie"
            ~to_id:"03.11-fifth-species")
        "03.03-battle-taunie, 03.10-fourth-species, 03.11-fifth-species then \
         none";
      case "a leading part two ids share is refused"
        (fun () -> select_text [ "01-a"; "01-b" ] ~from_id:"01" ~to_id:"01-b")
        "error: 01 names more than one checkpoint: 01-a, 01-b";
      case "a part not followed by a dash names nothing"
        (fun () -> select_text plza_ids ~from_id:"03.0" ~to_id:"03.10")
        "error: no checkpoint 03.0";
      case "the ids from one on"
        (fun () -> String.concat ", " (F.drop_until "mg-05" ids))
        "mg-05, mg-06";
      case "the id before one, none before the first"
        (fun () ->
          Option.value (F.previous ids "mg-05") ~default:"none"
          ^ " / "
          ^ Option.value (F.previous ids "mg-01") ~default:"none")
        "mg-05a / none";
      case "the id after one, none after the last"
        (fun () ->
          Option.value (F.next ids "mg-05") ~default:"none"
          ^ " / "
          ^ Option.value (F.next ids "mg-06") ~default:"none")
        "mg-06 / none";
      case "a checkpoint's plan file: <id>.plan.json in the folder"
        (fun () ->
          string_of_bool
            (F.plan_file ~plan_dir:"plans" "mg-04"
            = Filename.concat "plans" "mg-04.plan.json"))
        "true";
    ]
