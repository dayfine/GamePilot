let preflight_steps =
  [ "soft_reset"; "check_start"; "read_party"; "read_trainer_card"; "verdict" ]

let make_room_steps = [ "soft_reset"; "read_party"; "plan_deposit" ]

let event id =
  `Assoc
    [
      ("id", `String id);
      ("kind", `String "game_action");
      ("action", `String id);
      ("why", `String id);
    ]

let checkpoint ~id ~title steps =
  `Assoc
    [
      ("id", `String id);
      ("title", `String title);
      ("events", `List (List.map event steps));
    ]

let json ~id ~title steps =
  `Assoc
    [
      ("format", `String Checkpoints.Plan_decode.format);
      ("game", `String "frlg");
      ("checkpoint", checkpoint ~id ~title steps);
      ("execution", `Assoc [ ("menu", `String "full") ]);
      ("metadata", `Assoc [ ("phase", `String "generated") ]);
    ]

let plan ~id ~title steps =
  match Checkpoints.Plan_decode.decode ~source:id (json ~id ~title steps) with
  | Ok plan -> plan
  | Error e -> invalid_arg ("Shadow_plan.plan: " ^ e)
