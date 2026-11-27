(* Run_args: gamepilot run's args and the old commands' forms. *)

let show = function Ok t -> Run_args.command_line t | Error e -> "error: " ^ e
let run args () = show (Run_args.parse args)

let old command args () =
  match Run_args.of_old_command command args with
  | Not_old_command -> "none"
  | Invalid_old_args e -> "error: " ^ e
  | Run t -> Run_args.command_line t

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "run_args"
    [
      case "a program with --console"
        (run [ "frlg.supplies"; "--console" ])
        "gamepilot run frlg.supplies --console";
      case "a chain with its flags"
        (run [ "frlg.mail_glitch"; "--from"; "mg-01"; "--mode"; "testing" ])
        "gamepilot run frlg.mail_glitch --from mg-01 --mode testing";
      case "--program anywhere"
        (run [ "--from"; "a"; "--program"; "frlg.mail_glitch"; "--to"; "b" ])
        "gamepilot run frlg.mail_glitch --from a --to b";
      case "a plan folder: a path"
        (run [ "./plans"; "--preflight" ])
        "gamepilot run ./plans --preflight";
      case "a longer path"
        (run
           [
             "src/games/pokemon/frlg/programs/mail_glitch/plans"; "--from"; "a";
           ])
        "gamepilot run src/games/pokemon/frlg/programs/mail_glitch/plans \
         --from a";
      case "a bare name is a program id, whatever folders there are"
        (fun () ->
          match Run_args.parse [ "plans"; "--preflight" ] with
          | Ok { target = Program id; _ } -> "program " ^ id
          | Ok _ -> "not a program"
          | Error e -> "error: " ^ e)
        "program plans";
      case "--plan-dir anywhere"
        (run [ "--from"; "a"; "--plan-dir"; "plans" ])
        "gamepilot run --plan-dir plans --from a";
      case "--plan-dir with a path"
        (run [ "--plan-dir"; "some/plans" ])
        "gamepilot run some/plans";
      case "--plan-dir and --program"
        (run [ "--plan-dir"; "plans"; "--program"; "x" ])
        "error: --plan, --program and --plan-dir: give one";
      case "--plan anywhere"
        (run [ "--port"; "1"; "--plan"; "a.plan.json" ])
        "gamepilot run --plan a.plan.json --port 1";
      case "--plan and --program"
        (run [ "--plan"; "a.json"; "--program"; "x" ])
        "error: --plan, --program and --plan-dir: give one";
      case "--plan with no file" (run [ "--plan" ])
        "error: --plan needs a value";
      case "nothing to run"
        (run [ "--from"; "a" ])
        "error: a program id, a plan folder (a path, or --plan-dir DIR) or \
         --plan FILE is required";
      case "no args" (run [])
        "error: a program id, a plan folder (a path, or --plan-dir DIR) or \
         --plan FILE is required";
      case "quoted where the shell needs it"
        (run [ "x"; "--party"; "MR. MIME,FARFETCH'D" ])
        "gamepilot run x --party 'MR. MIME,FARFETCH'\\''D'";
      case "checkpoints --program"
        (old "checkpoints" [ "--program"; "frlg.mail_glitch"; "--from"; "a" ])
        "gamepilot run frlg.mail_glitch --from a";
      case "checkpoints PLAN_DIR"
        (old "checkpoints" [ "some/dir"; "--from"; "a" ])
        "gamepilot run some/dir --from a";
      case "checkpoints with a bare folder name"
        (old "checkpoints" [ "plans"; "--from"; "a" ])
        "gamepilot run --plan-dir plans --from a";
      case "checkpoint PLAN"
        (old "checkpoint" [ "a.plan.json"; "--walk" ])
        "gamepilot run --plan a.plan.json --walk";
      case "checkpoint with no plan" (old "checkpoint" [])
        "error: a plan file is required";
      case "another command" (old "status" []) "none";
      case "the notice"
        (fun () ->
          Run_args.old_command_notice "checkpoints"
            { target = Program "frlg.mail_glitch"; flags = [ "--from"; "a" ] })
        "gamepilot checkpoints is now gamepilot run: gamepilot run \
         frlg.mail_glitch --from a";
    ]
