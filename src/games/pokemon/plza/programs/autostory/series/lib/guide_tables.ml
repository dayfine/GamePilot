let ( let* ) = Result.bind

let row ~plan_dir id =
  Result.map
    (fun (plan : Plza_checkpoints.Plan.t) ->
      Printf.sprintf "| %s | %s |" plan.checkpoint.checkpoint_id
        (Guide_page.cell plan.checkpoint.title))
    (Runs.load_plan ~plan_dir id)

let rows ~plan_dir ids =
  List.fold_left
    (fun acc id ->
      let* acc = acc in
      let* r = row ~plan_dir id in
      Ok (acc @ [ r ]))
    (Ok []) ids

let commands ~args =
  String.concat "\n"
    [
      "# the Switch: each checkpoint once, from where the console is";
      "cd src && opam exec -- dune exec -- gamepilot checkpoints " ^ args
      ^ " --mode testing --backend switch --serial PORT --capture DEVICE \\";
      "    --watch";
    ]
