(* The scripted battle runner against a driver that answers from lists: the
   events the battle reports in order, and the results of the moves chosen.
   Each case gives the driver's calls and the outcome. The battles are the
   fork's Mail Glitch ones (MailGlitchBattle.cpp, and #804's PR C acceptance
   list). *)

open Frlg_battle

type fake = {
  events : Battle_driver.event list;
  moves : Battle_driver.move_result list;  (** default [Chosen] *)
  switch_ok : bool;
  send_in_ok : bool;
  offered : string option list;
      (** the moves offered at each move learn, as read; default unread *)
}

let fake ?(moves = []) ?(switch_ok = true) ?(send_in_ok = true) ?(offered = [])
    events =
  { events; moves; switch_ok; send_in_ok; offered }

(* The driver's answer from what the list shows. *)
let learned offered : Battle_driver.learn -> Battle_driver.learned = function
  | Keep_moves -> Not_learned { offered = None }
  | Forget slot -> Learned { slot; move = offered }
  | Forget_for { move; slot } -> (
      match offered with
      | Some m when m = move -> Learned { slot; move = offered }
      | Some _ -> Not_learned { offered }
      | None -> Unread "the move offered did not read")

let learn_name : Battle_driver.learn -> string = function
  | Keep_moves -> "keep moves"
  | Forget s -> Printf.sprintf "forget %d" s
  | Forget_for { move; slot } -> Printf.sprintf "forget %d for %s" slot move

let take q ~default = Option.value (Queue.take_opt q) ~default

let driver f calls : Battle_driver.t =
  let events = Queue.of_seq (List.to_seq f.events) in
  let moves = Queue.of_seq (List.to_seq f.moves) in
  let offered = Queue.of_seq (List.to_seq f.offered) in
  let call s = calls := s :: !calls in
  {
    next_event = (fun ~timeout_ms:_ -> take events ~default:Timed_out);
    use_move =
      (fun ~slot ~target ~expect ->
        call
          (Printf.sprintf "move %d %s%s" slot
             (Battle_driver.target_name target)
             (match expect with Some n -> " " ^ n | None -> ""));
        take moves ~default:Battle_driver.Chosen);
    switch_to =
      (fun ~slot ->
        call (Printf.sprintf "switch %d" slot);
        f.switch_ok);
    send_in =
      (fun ~slot ->
        call (Printf.sprintf "send %d" slot);
        f.send_in_ok);
    run = (fun () -> call "run");
    use_item =
      (fun item ->
        call (Printf.sprintf "item %d" item.row);
        true);
    answer_move_learn =
      (fun learn ->
        let result = learned (take offered ~default:None) learn in
        call
          (learn_name learn ^ " (" ^ Battle_driver.describe_learned result ^ ")");
        result);
    answer_use_next = (fun yes -> call (if yes then "next yes" else "next no"));
  }

let played f script () =
  let calls = ref [] in
  let outcome = Scripted_battle.run (driver f calls) script in
  let calls =
    if !calls = [] then "no calls" else String.concat "; " (List.rev !calls)
  in
  calls ^ " => " ^ Scripted_battle.describe outcome

let case name f script expectation : Case_table.case =
  { name; input = played f script; expectation }

let menus n = List.init n (fun _ -> Battle_driver.Action_menu)
let move ?name slot target = Battle_script.Move { slot; target; name }

(* The old Route 8 mg-05: Knock Off on the ally, MIMIEN in, the sweeper in,
   Recycle. *)
let double_opening =
  [
    move ~name:"knock-off" 0 Ally;
    Switch 2;
    Switch 3;
    move ~name:"recycle" 1 Default;
  ]

let double_battle_cases =
  [
    case "double battle: setup, then Surf hits both foes"
      (fake (menus 6 @ [ Battle_over ]))
      (Battle_script.make ~opening:double_opening
         (Attack { slots = [ 0 ]; target = Default }))
      "move 0 ally knock-off; switch 2; switch 3; move 1 default recycle; move \
       0 default; move 0 default => over (6 menus, 0 send-ins, 0 refused, 0 \
       prompts)";
    case "double battle: single-target sweep, a faint sends in slot 3"
      (fake (menus 5 @ [ Switch_in; Action_menu; Battle_over ]))
      (Battle_script.make ~opening:double_opening
         ~send_ins:[ { slot = 3; then_ = None } ]
         (Attack { slots = [ 2 ]; target = Foe_left }))
      "move 0 ally knock-off; switch 2; switch 3; move 1 default recycle; move \
       2 foe left; send 3; move 2 foe left => over (6 menus, 1 send-ins, 0 \
       refused, 0 prompts)";
    case "double battle: a slot that holds another move stops the script"
      (fake ~moves:[ Other_move "growl" ] (menus 1))
      (Battle_script.make ~opening:double_opening Stop)
      "move 0 ally knock-off => failed: move slot 0 holds growl (1 menus, 0 \
       send-ins, 0 refused, 0 prompts)";
    case "double battle: a refused switch stops the script"
      (fake ~switch_ok:false (menus 2))
      (Battle_script.make ~opening:double_opening Stop)
      "move 0 ally knock-off; switch 2 => failed: the switch to slot 2 was \
       refused (2 menus, 0 send-ins, 0 refused, 0 prompts)";
  ]

(* mg-04: the trainee leads, the sweeper (slot 1) comes in and fights. *)
let switch_grind =
  Battle_script.make ~opening:[ Switch 1 ]
    ~send_ins:[ { slot = 1; then_ = None } ]
    ~learn:(Forget_for { move = "recycle"; slot = 0 })
    (Attack { slots = [ 0; 1 ]; target = Default })

let switch_grind_cases =
  [
    case "switch-grind: switch, a move out of PP rotates, the move learned"
      (fake ~moves:[ Chosen; Refused ] ~offered:[ Some "recycle" ]
         (menus 4 @ [ Move_learn; Battle_over ]))
      switch_grind
      "switch 1; move 0 default; move 0 default; move 1 default; forget 0 for \
       recycle (learned recycle over move 0) => over (4 menus, 0 send-ins, 1 \
       refused, 1 prompts, learned recycle)";
    case "switch-grind: another move offered is not learned"
      (fake
         ~offered:[ Some "light-screen"; Some "reflect" ]
         (menus 2 @ [ Move_learn; Move_learn; Battle_over ]))
      switch_grind
      "switch 1; move 0 default; forget 0 for recycle (not learned: \
       light-screen); forget 0 for recycle (not learned: reflect) => over (2 \
       menus, 0 send-ins, 0 refused, 2 prompts)";
    case "switch-grind: an unread offer is asked again, then read"
      (fake ~offered:[ None; Some "recycle" ]
         [ Move_learn; Move_learn; Battle_over ])
      switch_grind
      "forget 0 for recycle (unread: the move offered did not read); forget 0 \
       for recycle (learned recycle over move 0) => over (0 menus, 0 send-ins, \
       0 refused, 2 prompts, learned recycle)";
    case "switch-grind: an offer unread three times fails the battle"
      (fake [ Move_learn; Move_learn; Move_learn; Battle_over ])
      switch_grind
      "forget 0 for recycle (unread: the move offered did not read); forget 0 \
       for recycle (unread: the move offered did not read); forget 0 for \
       recycle (unread: the move offered did not read) => failed: the move \
       learn did not read 3 times: the move offered did not read (0 menus, 0 \
       send-ins, 0 refused, 3 prompts)";
    case
      "switch-grind: the trainee faints first, the sweeper is sent in and \
       fights"
      (fake [ Switch_in; Action_menu; Battle_over ])
      switch_grind
      "send 1; move 0 default => over (1 menus, 1 send-ins, 0 refused, 0 \
       prompts)";
    case "switch-grind: the sweeper fainting fails the battle"
      (fake [ Action_menu; Action_menu; Switch_in; Switch_in ])
      switch_grind
      "switch 1; move 0 default; send 1 => failed: a member fainted and the \
       script sends in no more (2 menus, 1 send-ins, 0 refused, 0 prompts)";
    case "switch-grind: every move out of PP fails the battle"
      (fake ~moves:[ Refused; Refused ] (menus 4))
      switch_grind
      "switch 1; move 0 default; move 1 default => failed: every attack slot \
       was refused (4 menus, 0 send-ins, 2 refused, 0 prompts)";
  ]

(* The old Route 8 mg-05: the Berry holder attacks until it faints, the sweeper
   flees. *)
let faint_and_flee =
  Battle_script.make
    ~send_ins:[ { slot = 1; then_ = Some Flee } ]
    (Attack { slots = [ 0 ]; target = Default })

let other_cases =
  [
    case "faint-and-flee: attack until the faint, send the sweeper, run"
      (fake (menus 2 @ [ Switch_in; Action_menu; Battle_over ]))
      faint_and_flee
      "move 0 default; move 0 default; send 1; run => over (3 menus, 1 \
       send-ins, 0 refused, 0 prompts)";
    case "flee: a failed escape runs again"
      (fake (menus 2 @ [ Battle_over ]))
      (Battle_script.make Flee)
      "run; run => over (2 menus, 0 send-ins, 0 refused, 0 prompts)";
    case "use next: NO, as the script says"
      (fake [ Use_next; Battle_over ])
      (Battle_script.make Flee)
      "next no => over (0 menus, 0 send-ins, 0 refused, 1 prompts)";
    case "move learn: the moves kept when the script forgets none"
      (fake [ Move_learn; Move_learn; Battle_over ])
      (Battle_script.make Flee)
      "keep moves (not learned: unread move); keep moves (not learned: unread \
       move) => over (0 menus, 0 send-ins, 0 refused, 2 prompts)";
    case "an item, then the fallback"
      (fake (menus 2 @ [ Battle_over ]))
      (Battle_script.make
         ~opening:[ Item { pocket = Items; row = 2; on_slot = Some 0 } ]
         Flee)
      "item 2; run => over (2 menus, 0 send-ins, 0 refused, 0 prompts)";
    case "stop: an action menu after the opening fails"
      (fake (menus 2))
      (Battle_script.make ~opening:[ Run ] Stop)
      "run => failed: an action menu after the script's last command (2 menus, \
       0 send-ins, 0 refused, 0 prompts)";
    case "no event in time fails" (fake [])
      (Battle_script.make ~event_timeout_ms:5000 Flee)
      "no calls => failed: no battle event within 5000 ms (0 menus, 0 \
       send-ins, 0 refused, 0 prompts)";
    case "more menus than allowed fail"
      (fake (menus 3))
      (Battle_script.make ~max_menus:2 Flee)
      "run; run => failed: more than 2 action menus (3 menus, 0 send-ins, 0 \
       refused, 0 prompts)";
  ]

let () =
  Case_table.run "scripted battle"
    (double_battle_cases @ switch_grind_cases @ other_cases)
