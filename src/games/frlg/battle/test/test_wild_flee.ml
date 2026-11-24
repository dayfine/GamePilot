(* Running from a wild battle against a driver that answers from a list of
   events: the RUNs chosen and the outcome. *)

open Frlg_battle

(* A flee only reads events and presses RUN; any other verb fails the test. *)
let not_a_flee_verb () = failwith "not a flee's verb"

let driver events runs : Battle_driver.t =
  let events = Queue.of_seq (List.to_seq events) in
  {
    next_event =
      (fun ~timeout_ms:_ ->
        Option.value (Queue.take_opt events) ~default:Battle_driver.Timed_out);
    use_move = (fun ~slot:_ ~target:_ ~expect:_ -> not_a_flee_verb ());
    switch_to = (fun ~slot:_ -> not_a_flee_verb ());
    send_in = (fun ~slot:_ -> not_a_flee_verb ());
    run = (fun () -> incr runs);
    use_item = (fun _ -> not_a_flee_verb ());
    answer_move_learn = (fun _ -> not_a_flee_verb ());
    answer_use_next = (fun _ -> not_a_flee_verb ());
  }

let fled events () =
  let runs = ref 0 in
  let lines = ref [] in
  let outcome =
    Wild_flee.run (driver events runs) ~log:(fun l -> lines := l :: !lines)
  in
  String.concat "\n"
    ((Wild_flee.describe outcome :: List.rev !lines)
    @ [ Printf.sprintf "%d RUNs pressed" !runs ])

let case name input expectation = { Table_test.name; input; expectation }
let menus n = List.init n (fun _ -> Battle_driver.Action_menu)

let () =
  Table_test.run "wild_flee"
    [
      case "RUN on the action menu, then the battle is over"
        (fled [ Action_menu; Battle_over ])
        "fled after 1 RUNs\nWild battle: RUN.\n1 RUNs pressed";
      case "Can't escape!: the menu comes back and gets RUN again"
        (fled [ Action_menu; Action_menu; Battle_over ])
        "fled after 2 RUNs\n\
         Wild battle: RUN.\n\
         Wild battle: RUN again (refused 1).\n\
         2 RUNs pressed";
      case "a trainer's battle refuses every RUN: reported, not fled"
        (fled (menus 6))
        "not fled: the action menu came back after 5 RUNs: a trainer's battle, \
         or a foe that bars escape\n\
         Wild battle: RUN.\n\
         Wild battle: RUN again (refused 1).\n\
         Wild battle: RUN again (refused 2).\n\
         Wild battle: RUN again (refused 3).\n\
         Wild battle: RUN again (refused 4).\n\
         5 RUNs pressed";
      case "no action menu ever: reported, nothing pressed" (fled [])
        "not fled: timed out after 0 RUNs\n0 RUNs pressed";
      case "a party list where the menu should be: reported"
        (fled [ Action_menu; Switch_in ])
        "not fled: switch-in after 1 RUNs\nWild battle: RUN.\n1 RUNs pressed";
    ]
