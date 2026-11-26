(* The scripted battle runner against fake game steps that answer from lists: the
   events the battle reports in order, the results of the moves chosen, and
   Level_up's fake game steps for level-ups, move learns and evolutions.
   Each case gives the game steps' calls and the outcome. The battles are the
   fork's Mail Glitch ones (MailGlitchBattle.cpp, and #804's PR C acceptance
   list). *)

open Frlg_battle

type fake = {
  events : Battle.event list;
  moves : Battle.move_result list;  (** default [Chosen] *)
  switch_ok : bool;
  send_in_ok : bool;
  looks : Level_up.look list;
  lists : Level_up.forget_list list;
}

let fake ?(moves = []) ?(switch_ok = true) ?(send_in_ok = true) ?(looks = [])
    ?(lists = []) events =
  { events; moves; switch_ok; send_in_ok; looks; lists }

let take q ~default = Option.value (Queue.take_opt q) ~default

let fake_game_steps f calls : Battle.game_steps * Level_up_fake.game =
  let events = Queue.of_seq (List.to_seq f.events) in
  let moves = Queue.of_seq (List.to_seq f.moves) in
  let level_up_game = Level_up_fake.game ~lists:f.lists f.looks in
  let call s = calls := s :: !calls in
  ( {
      next_event = (fun ~timeout_ms:_ -> take events ~default:Timed_out);
      use_move =
        (fun ~slot ~target ~expect ->
          call
            (Printf.sprintf "move %d %s%s" slot
               (Battle.target_name target)
               (match expect with Some n -> " " ^ n | None -> ""));
          take moves ~default:Battle.Chosen);
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
      level_up = Level_up_fake.fake_game_steps level_up_game;
      answer_use_next =
        (fun yes -> call (if yes then "next yes" else "next no"));
    },
    level_up_game )

let played f script () =
  let calls = ref [] in
  let steps, level_up_game = fake_game_steps f calls in
  let outcome = Scripted_battle.run steps script in
  let calls =
    if !calls = [] then "no calls" else String.concat "; " (List.rev !calls)
  in
  let trace =
    match List.rev level_up_game.trace with
    | [] -> ""
    | steps -> " [" ^ String.concat ", " steps ^ "]"
  in
  calls ^ trace ^ " => " ^ Scripted_battle.describe outcome

let case name f script expectation : Table_test.case =
  { name; input = played f script; expectation }

let menus n = List.init n (fun _ -> Battle.Action_menu)
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

let recycle_policy =
  Level_up_policy.for_everyone
    { rules = [ { learn = "recycle"; replacing = Slot 0 } ]; evolve = false }

(* mg-04: the trainee leads, the sweeper (slot 1) comes in and fights. *)
let switch_grind =
  Battle_script.make ~opening:[ Switch 1 ]
    ~send_ins:[ { slot = 1; then_ = None } ]
    ~switch_refused:Flee ~level_up:recycle_policy
    (Attack { slots = [ 0; 1 ]; target = Default })

let stats = Level_up.Stats None
let evolving = Level_up.Evolving None

let switch_grind_cases =
  [
    case "switch-grind: switch, a move out of PP rotates, the move learned"
      (fake ~moves:[ Chosen; Refused ]
         ~looks:[ stats; Move_prompt; Back ]
         ~lists:[ Level_up_fake.offer "recycle" ]
         (menus 4 @ [ Level_up; Battle_over ]))
      switch_grind
      "switch 1; move 0 default; move 0 default; move 1 default [yes, forget \
       0] => over (4 menus, 0 send-ins, 1 refused, 1 prompts, learned recycle)";
    case "switch-grind: other moves offered are declined"
      (fake
         ~looks:[ stats; Move_prompt; Move_prompt; Back ]
         ~lists:
           [ Level_up_fake.offer "light-screen"; Level_up_fake.offer "reflect" ]
         (menus 2 @ [ Level_up; Battle_over ]))
      switch_grind
      "switch 1; move 0 default [yes, leave, yes, leave] => over (2 menus, 0 \
       send-ins, 0 refused, 1 prompts)";
    case "switch-grind: an unread offer is declined by Level_up"
      (fake
         ~looks:[ stats; Move_prompt; Back ]
         ~lists:[ { offered = None; known = Level_up_fake.known } ]
         [ Level_up; Battle_over ])
      switch_grind
      "no calls [yes, leave] => over (0 menus, 0 send-ins, 0 refused, 1 \
       prompts)";
    case "switch-grind: a level-up timeout fails the battle"
      (fake ~looks:[ stats ] [ Level_up; Battle_over ])
      switch_grind
      "no calls => failed: level up: nothing to answer showed (0 menus, 0 \
       send-ins, 0 refused, 1 prompts)";
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
    case
      "switch-grind: the sweeper fainted in an earlier battle (\"has no energy \
       left to battle!\", mg-04b testing 6): the switch refused, RUN"
      (fake ~switch_ok:false (menus 2 @ [ Battle_over ]))
      switch_grind
      "switch 1; run => over (2 menus, 0 send-ins, 0 refused, 0 prompts, 1 \
       switch refused)";
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

let evolve_script =
  Battle_script.make
    ~level_up:(Level_up_policy.for_everyone { rules = []; evolve = true })
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
    case "a trainer's switch offer: NO, whatever the script's use next"
      (fake [ Action_menu; Switch_offer; Action_menu; Battle_over ])
      (Battle_script.make ~use_next:true
         (Attack { slots = [ 0 ]; target = Default }))
      "move 0 default; next no; move 0 default => over (2 menus, 0 send-ins, 0 \
       refused, 1 prompts)";
    case "move learn: the moves kept when the script declines all"
      (fake
         ~looks:[ stats; Move_prompt; Move_prompt; Back ]
         [ Level_up; Battle_over ])
      (Battle_script.make Flee)
      "no calls [no, no] => over (0 menus, 0 send-ins, 0 refused, 1 prompts)";
    case "evolution cancelled when policy declines evolution"
      (fake ~looks:[ stats; evolving; Back ] [ Level_up; Battle_over ])
      (Battle_script.make Flee)
      "no calls [hold B] => over (0 menus, 0 send-ins, 0 refused, 1 prompts)";
    case "evolution let run across two phases of a trainer battle"
      (fake
         ~looks:[ stats; Back; evolving; Back ]
         [ Action_menu; Level_up; Action_menu; Evolution; Battle_over ])
      evolve_script
      "move 0 default; move 0 default [wait] => over (2 menus, 0 send-ins, 0 \
       refused, 2 prompts)";
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
  Table_test.run "scripted battle"
    (double_battle_cases @ switch_grind_cases @ other_cases)
