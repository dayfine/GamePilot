(* The checkpoints' run order from their ids. *)

let sorted ids () =
  String.concat ", " (List.sort Checkpoints_series.Checkpoint_order.compare ids)

let case name input expectation = { Table_test.name; input; expectation }

(* The Mail Glitch folder's plans, as the series lists them. *)
let mail_glitch_chain () =
  Plan_files.plans_in Plan_files.mail_glitch_dir
  |> List.map (fun path ->
         Filename.chop_suffix (Filename.basename path) ".plan.json")
  |> sorted
  |> fun order -> order ()

let () =
  Table_test.run "checkpoint_order"
    [
      case
        "mail glitch: mg-05a before mg-05 (mg-04 testing 15 ended at mg-05's \
         start)"
        (sorted [ "mg-06"; "mg-05"; "mg-05a"; "mg-04"; "mg-01" ])
        "mg-01, mg-04, mg-05a, mg-05, mg-06";
      case
        "the Mail Glitch chain: mg-04 split in three, its grind round between"
        mail_glitch_chain
        "mg-01, mg-02, mg-03, mg-04a, mg-04b, mg-04c, mg-05a, mg-05, mg-06";
      case "parts in letter order, before the bare id"
        (sorted [ "cp-2"; "cp-2b"; "cp-2a"; "cp-10" ])
        "cp-10, cp-2a, cp-2b, cp-2";
      case "letters not after a digit are part of the name"
        (sorted [ "intro"; "intra" ])
        "intra, intro";
    ]
