(* The Mail Glitch plans' run order from their ids (Checkpoint_order). *)

let sorted ids () =
  String.concat ", " (List.sort Engine_series.Checkpoint_order.compare ids)

let case name input expectation = { Table_test.name; input; expectation }

(* The Mail Glitch folder's plans, as the series lists them. *)
let mail_glitch_chain () =
  Plan_files.plans_in Plan_files.mail_glitch_dir
  |> List.map (fun path ->
         Filename.chop_suffix (Filename.basename path) ".plan.json")
  |> sorted
  |> fun order -> order ()

let () =
  Table_test.run "checkpoint_order plans"
    [
      case "the Mail Glitch chain, in its ids' number order" mail_glitch_chain
        "01-celadon-setup, 02-trade-farfetchd, 03-trade-mr-mime, \
         04-grind-farfetchd, 05-grind-mr-mime, 06-grind-return, \
         07-glitch-prep, 08-activate-and-verify";
    ]
