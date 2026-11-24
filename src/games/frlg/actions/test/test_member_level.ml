(* Member_level on a scripted screen (Scripted_screen): the member's level
   read off its summary, from the overworld and back to it; and one grind
   battle on a fake rig whose level reads go through that screen. *)

open Frlg_actions
module S = Frlg_overworld_fixtures.Scripted_screen
module B = Frlg_battle

let case name input expectation = { Case_table.name; input; expectation }

(* START opens the menu on POKéMON; A on it the party; A on a slot its menu;
   A on SUMMARY (row 0) the summary, at the next of [levels] (the last one
   again once used up; [None]: a page with no level on it). B steps back one
   screen. *)
let party_screen levels =
  let levels = ref levels and slot = ref 1 in
  let next () =
    let level = List.hd !levels in
    if List.tl !levels <> [] then levels := List.tl !levels;
    match level with
    | Some l -> S.Summary_at ("MR. MIME", l)
    | None -> S.Summary "MR. MIME"
  in
  fun screen (p : S.press) ->
    let show s = S.show screen ~at_ms:(p.at_ms + 200) s in
    match (p.buttons, S.screen_at screen p.at_ms) with
    | [ Wire.Start ], _ -> show (S.Start_menu 1)
    | [ Wire.A ], S.Start_menu 1 -> show (S.Party 1)
    | [ Wire.A ], S.Party s ->
        slot := s;
        show (S.Member_menu 0)
    | [ Wire.A ], S.Member_menu 0 -> show (next ())
    | [ Wire.B ], (S.Summary _ | S.Summary_at _) -> show (S.Member_menu 0)
    | [ Wire.B ], S.Member_menu _ -> show (S.Party !slot)
    | [ Wire.B ], S.Party _ -> show S.Overworld
    | _ -> ()

let ends_on screen = S.screen_name (S.screen_at screen screen.S.clock_ms)

let outcome = function
  | Ok () -> "ok"
  | Error cause -> "failed " ^ Story.Failure.cause_to_string cause

let level_text = Option.fold ~none:"unread" ~some:(Printf.sprintf "Lv %d")

let read_level levels () =
  let screen = S.create ~react:(party_screen levels) () in
  let level = ref None in
  let result =
    S.run screen (fun () ->
        Menu_input.run (fun () ->
            level := Member_level.read ~log:ignore ~slot:1))
  in
  Printf.sprintf "%s, %s; ends on %s" (outcome result) (level_text !level)
    (ends_on screen)

(* Switch on turn 1, the sweeper's KO: the battle is over. *)
let won_driver calls : B.Battle_driver.t =
  let events =
    Queue.of_seq
      (List.to_seq B.Battle_driver.[ Action_menu; Action_menu; Battle_over ])
  in
  let call s = calls := s :: !calls in
  {
    next_event =
      (fun ~timeout_ms:_ ->
        Option.value (Queue.take_opt events) ~default:B.Battle_driver.Timed_out);
    use_move =
      (fun ~slot ~target:_ ~expect:_ ->
        call (Printf.sprintf "move %d" slot);
        Chosen);
    switch_to =
      (fun ~slot ->
        call (Printf.sprintf "switch %d" slot);
        true);
    send_in = (fun ~slot:_ -> true);
    run = (fun () -> ());
    use_item = (fun _ -> true);
    answer_move_learn = (fun _ -> Not_learned { offered = None });
    answer_use_next = (fun _ -> ());
  }

let strategies = Result.get_ok (Grind_plan.load_strategies ())

let mimien =
  Result.get_ok
    (Grind_plan.decode strategies
       (Grid_maps.Json_field.as_object ""
          (Yojson.Safe.from_string
             {|{"species": "mr-mime", "target_level": 33, "learn_move": "recycle",
                "learn_slot": 1, "sweeper": "blastoise", "sweeper_moves": [1, 2],
                "max_battles": 120}|})))

(* The grinder in slot 1 and the sweeper in 2 already: no swaps. Walks, heals
   and the wait for a battle are calls; the battle and the level reads run on
   the scripted screen. *)
let grind levels () =
  let screen = S.create ~react:(party_screen levels) () in
  let calls = ref [] in
  let call s = calls := s :: !calls in
  let party = Party_roster.of_list [ "mr-mime"; "blastoise" ] in
  let rig : Grind.rig =
    {
      slot_of = Party_roster.slot_of party;
      known_moves = (fun ~slot:_ -> [ "barrier" ]);
      level = (fun ~slot -> Member_level.read ~log:ignore ~slot);
      swap = (fun a b -> call (Printf.sprintf "swap %d %d" a b));
      go_to = (fun g -> call ("go " ^ g.Story.Pose.map));
      heal = (fun _ -> call "heal");
      find_battle = (fun () -> call "spin");
      battle = (fun script -> B.Scripted_battle.run (won_driver calls) script);
      log =
        (fun line ->
          if
            String.starts_with ~prefix:"Grind: battle" line
            || String.starts_with ~prefix:"Grind: mr-mime reached" line
          then call line);
    }
  in
  let result =
    S.run screen (fun () -> Menu_input.run (fun () -> Grind.run rig mimien))
  in
  Printf.sprintf "%s => %s; ends on %s"
    (String.concat "; " (List.rev !calls))
    (outcome result) (ends_on screen)

let () =
  Case_table.run "member_level"
    [
      case "Lv 33 on the summary, back on the overworld"
        (read_level [ Some 33 ]) "ok, Lv 33; ends on overworld";
      case "Lv 100: three digits" (read_level [ Some 100 ])
        "ok, Lv 100; ends on overworld";
      case "no level on the page: unread, still back on the overworld"
        (read_level [ None ]) "ok, unread; ends on overworld";
      case "one battle at Lv 32, Lv 33 read after it: reached, healed"
        (grind [ Some 32; Some 33 ])
        "go VictoryRoad_2F; spin; switch 1; move 0; Grind: battle 1 of 120, Lv \
         33 over (2 menus, 0 send-ins, 0 refused, 0 prompts).; Grind: mr-mime \
         reached Lv 33 (target 33) in battle 1; did not learn recycle.; heal; \
         go VictoryRoad_2F => ok; ends on overworld";
    ]
