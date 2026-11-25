(* The shared actions' flows on a scripted screen read through the FRLG
   readers from recorded frames (Scripted_screen): what each presses, and
   that each waits on the screen it needs. *)

open Frlg_actions
open Frlg_overworld_fixtures
module S = Scripted_screen

let outcome = function
  | Ok () -> "ok"
  | Error cause -> "failed " ^ Pokemon_checkpoints.Failure.cause_to_string cause

let a p = p.S.buttons = [ Wire.A ]

(* A talk: A on the overworld (or a menu) shows a page with the arrow when
   [page], else the question; A on the page shows the question; A on the
   question (YES) shows text for [after_ms], then the overworld. *)
let talk ~page ~after_ms screen (p : S.press) =
  let show d s = S.show screen ~at_ms:(p.at_ms + d) s in
  if a p then
    match S.screen_at screen p.at_ms with
    | S.Overworld | S.Start_menu _ ->
        show 200 (if page then S.Dialog_arrow else S.Question)
    | S.Dialog_arrow ->
        show 100 S.Dialog;
        show 400 S.Question
    | S.Question ->
        show 100 S.Dialog;
        show (100 + after_ms) S.Overworld
    | _ -> ()

let run_on ?react summary body =
  let screen = S.create ?react () in
  let result = S.run screen (fun () -> Menu_input.run body) in
  Printf.sprintf "%s; %s" (outcome result) (summary screen)

let run ?react body = run_on ?react S.presses_text body
let log = ignore

let heal () =
  run ~react:(talk ~page:true ~after_ms:3000) (Heal_and_save.heal_at_nurse ~log)

(* The nurse as mGBA showed her (mg-03 testing run 1, Lavender Center): her
   Yes/No box is not where the question reader looks, so her pages and her
   question read as text boxes only. A on the overworld starts her talk, A on
   a page shows the next, the fourth A (YES) heals and the overworld comes
   back after [healing_ms]; B on any of her boxes ends the talk. *)
let healing_ms = 3000

let nurse_screen () =
  let pages = ref 0 in
  fun screen (p : S.press) ->
    let show d s = S.show screen ~at_ms:(p.at_ms + d) s in
    match (p.buttons, S.screen_at screen p.at_ms) with
    | [ Wire.A ], S.Overworld ->
        pages := 1;
        show 200 S.Dialog_arrow
    | [ Wire.A ], S.Dialog_arrow when !pages < 3 ->
        incr pages;
        show 100 S.Dialog;
        show 300 S.Dialog_arrow
    | [ Wire.A ], S.Dialog_arrow ->
        show 100 S.Dialog;
        show (100 + healing_ms) S.Overworld
    | [ Wire.B ], (S.Dialog | S.Dialog_arrow) -> show 100 S.Overworld
    | _ -> ()

let heal_unread_question () =
  run_on ~react:(nurse_screen ())
    (fun screen -> S.screen_name (S.screen_at screen screen.S.clock_ms))
    (Heal_and_save.heal_at_nurse ~log)

let heal_no_dialog () = run (Heal_and_save.heal_at_nurse ~log)

(* START opens the menu on row 1, B on it closes it; A on SAVE asks. *)
let save_screen screen (p : S.press) =
  match (p.buttons, S.screen_at screen p.at_ms) with
  | [ Wire.Start ], _ -> S.show screen ~at_ms:(p.at_ms + 100) (S.Start_menu 1)
  | [ Wire.B ], S.Start_menu _ ->
      S.show screen ~at_ms:(p.at_ms + 100) S.Overworld
  | _ -> talk ~page:false ~after_ms:2000 screen p

let save () = run ~react:save_screen (Heal_and_save.save ~log)

let cut () =
  run ~react:(talk ~page:true ~after_ms:1500) (fun () ->
      Cut_tree.cut ~log Grid_maps.Direction.North)

(* The Cut talk, its question dropping presses for its first
   [question_input_ms]: A then answers YES, B answers NO, each ending the talk.
   The summary adds the answer. *)
let question_input_ms = 100

let cut_slow_question () =
  let asked = ref max_int and answer = ref "none" in
  let react screen (p : S.press) =
    let on_question = S.screen_at screen p.at_ms = S.Question in
    let taken = p.at_ms - !asked >= question_input_ms in
    let answered word =
      answer := word;
      S.show screen ~at_ms:(p.at_ms + 100) S.Dialog;
      S.show screen ~at_ms:(p.at_ms + 1600) S.Overworld
    in
    match p.buttons with
    | [ Wire.A ] when on_question && taken && !answer = "none" -> answered "YES"
    | [ Wire.B ] when on_question && taken && !answer = "none" -> answered "NO"
    | _ when on_question -> ()
    | _ ->
        talk ~page:true ~after_ms:1500 screen p;
        if a p && S.screen_at screen p.at_ms = S.Dialog_arrow then
          asked := p.at_ms + 400
  in
  run_on ~react
    (fun screen ->
      let presses = S.presses_text screen in
      let before_b =
        match String.index_opt presses 'B' with
        | Some i -> String.sub presses 0 (i - 2)
        | None -> presses
      in
      Printf.sprintf "%s; answered %s" before_b !answer)
    (fun () -> Cut_tree.cut ~log Grid_maps.Direction.North)

(* A talk whose page drops an A for its first [page_input_ms] (the A only
   hurries the text): a later A shows the question, YES ends it. *)
let page_input_ms = 150

let slow_page () =
  let page_at = ref max_int in
  let react screen (p : S.press) =
    let show d s = S.show screen ~at_ms:(p.at_ms + d) s in
    if a p then
      match S.screen_at screen p.at_ms with
      | S.Overworld ->
          page_at := p.at_ms + 100;
          show 100 S.Dialog_arrow
      | S.Dialog_arrow when p.at_ms - !page_at >= page_input_ms ->
          show 100 S.Question
      | S.Question ->
          show 100 S.Dialog;
          show 1600 S.Overworld
      | _ -> ()
  in
  run ~react (fun () ->
      Menu_input.press Wire.A;
      Menu_input.answer_yes ~code:"no_question"
        ~taken:(fun _ -> false)
        "the offer")

(* Each A shows the next group of screens, each a delay after the press. *)
let on_each_a groups =
  let left = ref groups in
  fun screen (p : S.press) ->
    match !left with
    | group :: rest when a p ->
        left := rest;
        List.iter (fun (d, s) -> S.show screen ~at_ms:(p.at_ms + d) s) group
    | _ -> ()

(* The clerk's page, the choice box (no reader: a dialog), the question, then
   the prize's text. *)
let redeem ?(page = S.Dialog_arrow) () =
  run
    ~react:
      (on_each_a
         [
           [ (200, page) ];
           [ (100, S.Dialog) ];
           [ (300, S.Question) ];
           [ (100, S.Dialog); (2000, S.Overworld) ];
         ])
    (fun () -> Game_corner.redeem_prize_mon ~log 0)

(* START opens the menu on [start_row]; A on POKéMON the party, its cursor on
   [slot]; A on a slot opens its menu; A on SWITCH and on the second slot
   keep the party. The cursors move as the presses move them, once a menu has
   shown [input_delay_ms]. *)
let swap_screen ~start_row ~slot () =
  let switching = ref false and chosen = ref slot in
  fun screen (p : S.press) ->
    let show s = S.show screen ~at_ms:(p.at_ms + 200) s in
    match (p.buttons, S.screen_at screen p.at_ms) with
    | [ Wire.Start ], _ -> show (S.Start_menu start_row)
    | [ Wire.A ], S.Start_menu 1 -> show (S.Party slot)
    | [ Wire.A ], S.Start_menu _ -> show S.Black
    | [ Wire.A ], S.Party s when not !switching ->
        chosen := s;
        show (S.Member_menu 0)
    | [ Wire.A ], S.Member_menu 1 ->
        switching := true;
        show (S.Party !chosen)
    | [ Wire.B ], S.Party _ -> show S.Overworld
    | _ -> ()

(* START, POKéMON shows [party]; B on it the overworld. *)
let verify_screen party screen (p : S.press) =
  let show s = S.show screen ~at_ms:(p.at_ms + 100) s in
  match (p.buttons, S.screen_at screen p.at_ms) with
  | [ Wire.Start ], _ -> show (S.Start_menu 1)
  | [ Wire.A ], S.Start_menu 1 -> show party
  | [ Wire.B ], (S.Party _ | S.Party_after_recycle) -> show S.Overworld
  | _ -> ()

let verify party () =
  run ~react:(verify_screen party) (fun () ->
      Party_actions.verify_mail_glitch ~log ~who:"mr-mime" ~slot:3)

let swap ?(start_row = 1) ?(slot = 1) ?(input_delay_ms = 0) a b () =
  let screen =
    S.create ~react:(swap_screen ~start_row ~slot ()) ~input_delay_ms ()
  in
  let result =
    S.run screen (fun () ->
        Menu_input.run (fun () -> Party_actions.swap ~log a b))
  in
  Printf.sprintf "%s; %s" (outcome result) (S.presses_text screen)

(* A trade: the offer's question, the party, then the trade (black) and the
   trader's text. *)
let trade_screen screen (p : S.press) =
  let show d s = S.show screen ~at_ms:(p.at_ms + d) s in
  match S.screen_at screen p.at_ms with
  | S.Overworld when a p -> show 200 S.Question
  | S.Question when a p -> show 300 (S.Party 1)
  | S.Party _ when a p ->
      show 100 S.Black;
      show 5000 S.Dialog;
      show 7000 S.Overworld
  | _ -> ()

(* The party to give to shows; an A sooner than 300 ms after it is dropped
   (mGBA, mg-06 testing run 2), a later one on slot 1 shows the "already
   holding" page. *)
let give_to_slot_one () =
  let react screen (p : S.press) =
    if a p && p.at_ms >= 300 && S.screen_at screen p.at_ms = S.Party 1 then
      S.show screen ~at_ms:(p.at_ms + 100) S.Dialog_arrow
  in
  let screen = S.create ~react () in
  S.show screen ~at_ms:0 (S.Party 1);
  let result =
    S.run screen (fun () -> Menu_input.run (fun () -> Party_actions.give_to 1))
  in
  Printf.sprintf "%s; %s; ends on %s" (outcome result) (S.presses_text screen)
    (S.screen_name (S.screen_at screen (screen.S.clock_ms + 200)))

(* The item's menu shows; an A sooner than 500 ms after it is dropped (mGBA,
   mg-04 testing run 7: USE 165 ms after the menu showed, and the Escape Rope
   was never used), a later one on USE closes the bag for the rope. *)
let use_from_item_menu () =
  let react screen (p : S.press) =
    if a p && p.at_ms >= 500 && S.screen_at screen p.at_ms = S.Item_menu then
      S.show screen ~at_ms:(p.at_ms + 100) S.Black
  in
  let screen = S.create ~react () in
  S.show screen ~at_ms:0 S.Item_menu;
  let result =
    S.run screen (fun () ->
        Menu_input.run (fun () -> Bag_items.choose_in_item_menu "escape-rope" 0))
  in
  Printf.sprintf "%s; %s; ends on %s" (outcome result) (S.presses_text screen)
    (S.screen_name (S.screen_at screen (screen.S.clock_ms + 200)))

let trade () =
  run ~react:trade_screen (fun () -> Ingame_trade.trade ~log ~slot:3)

(* mg-02 testing run 2 (this branch): the trade scene's fade into its blue box
   read as the white text box for a frame or two; the settle after it then met
   the blue box ("Bye-bye, SPEAROW!"), which reads as a battle. Here the box
   (Battle) takes three A presses before the trader's text. *)
let trade_fade_screen screen (p : S.press) =
  let show d s = S.show screen ~at_ms:(p.at_ms + d) s in
  match S.screen_at screen p.at_ms with
  | S.Overworld when a p -> show 200 S.Question
  | S.Question when a p -> show 300 (S.Party 1)
  | S.Party _ when a p ->
      show 100 S.Black;
      show 1500 S.Dialog;
      show 1530 S.Battle
  | S.Battle when a p ->
      if List.length screen.S.presses >= 8 then (
        show 200 S.Dialog;
        show 2000 S.Overworld)
  | _ -> ()

let trade_fade () =
  run ~react:trade_fade_screen (fun () -> Ingame_trade.trade ~log ~slot:3)

(* A talk on console B, whose frames show the game [capture_latencies_ms]
   late, where the last page's A lands on the Yes/No box as it draws (mg-02
   testing, 2026-11-24, Elyssa): the talk's A shows page 1, A on it page 2,
   whose red text reads as the arrow while it prints; the box draws
   [print_ms] after that A, and an A from then on takes YES (its default) and
   shows [after_yes]. Times are the game's; each screen shows the press's
   latency later. [rest] scripts what follows. *)
let print_ms = 700
let latencies = [ 160; 335 ]

let latent_talk ~after_yes ?(rest = fun _ _ -> ()) () =
  let pages = ref 0 and asked_at = ref max_int and answered = ref false in
  fun screen (p : S.press) ->
    let late = S.latency_of screen p in
    let show d s = S.show screen ~at_ms:(p.at_ms + d + late) s in
    match !pages with
    | _ when !answered -> rest screen p
    | _ when not (a p) -> ()
    | _ when p.at_ms >= !asked_at ->
        answered := true;
        List.iter (fun (d, s) -> show d s) after_yes
    | 0 ->
        pages := 1;
        show 200 S.Dialog_arrow
    | 1 ->
        pages := 2;
        asked_at := p.at_ms + print_ms;
        show 100 S.Dialog_arrow;
        show print_ms S.Question
    | _ -> ()

let run_latent react body =
  let screen = S.create ~react ~capture_latencies_ms:latencies () in
  let result = S.run screen (fun () -> Menu_input.run body) in
  Printf.sprintf "%s; %s" (outcome result) (S.presses_text screen)

(* After the party: A on a slot, the trade (black), the trader's text, the
   overworld. *)
let after_party screen (p : S.press) =
  let show d s = S.show screen ~at_ms:(p.at_ms + d) s in
  match S.screen_at screen p.at_ms with
  | S.Party _ when a p ->
      show 100 S.Black;
      show 5000 S.Dialog;
      show 7000 S.Overworld
  | _ -> ()

let trade_yes_taken () =
  run_latent
    (latent_talk ~after_yes:[ (300, S.Party 1) ] ~rest:after_party ())
    (fun () -> Ingame_trade.trade ~log ~slot:3)

let cut_yes_taken () =
  run_latent
    (latent_talk ~after_yes:[ (100, S.Dialog); (1600, S.Overworld) ] ())
    (fun () -> Cut_tree.cut ~log Grid_maps.Direction.North)

(* A wild battle starts [after_ms] into the spin. *)
let spin ~after_ms () =
  run_on
    (fun screen -> Printf.sprintf "%d turns" (List.length screen.S.presses))
    ~react:(fun screen p ->
      if p.index = 0 then S.show screen ~at_ms:(p.at_ms + after_ms) S.Battle)
    (fun () -> Spin_for_encounter.spin ~log ~facing:North ~max_batches:2)

(* The clerk's text box shows 200 ms after A; its BUY/SELL box takes an A only
   [menu_ms] later (no reader: the text box), which opens the BUY list, whose
   cursor takes a tap only [menu_ms] after it shows. On the list, A on row 1
   asks how many, A on the quantity the price question, YES the list again; A
   on another row does nothing here. B on the list closes the Mart. *)
let mart_screen ~menu_ms =
  let text_at = ref max_int and list_at = ref max_int and row = ref 0 in
  fun screen (p : S.press) ->
    let show d s = S.show screen ~at_ms:(p.at_ms + d) s in
    match (p.buttons, S.screen_at screen p.at_ms) with
    | [ Wire.A ], S.Overworld ->
        text_at := p.at_ms + 200;
        show 200 S.Dialog
    | [ Wire.A ], S.Dialog when !row = 1 ->
        row := -1;
        show 300 S.Question
    | [ Wire.A ], S.Dialog when p.at_ms >= !text_at + menu_ms ->
        list_at := p.at_ms + 300;
        show 300 S.Mart_list
    | [ Wire.Down ], S.Mart_list when p.at_ms >= !list_at + menu_ms -> incr row
    | [ Wire.A ], S.Mart_list when !row = 1 -> show 300 S.Dialog
    | [ Wire.A ], S.Question -> show 300 S.Mart_list
    | [ Wire.B ], S.Mart_list -> show 300 S.Overworld
    | _ -> ()

(* Two Retro Mail at Celadon 4F: row 1, under POKé DOLL. *)
let mart_buy ~menu_ms () =
  let stock =
    [
      { Mart_plan.item = "poke-doll"; price = 1000 };
      { item = "retro-mail"; price = 50 };
    ]
  in
  let plan =
    {
      Mart_plan.map = "test";
      lines = [ { line_item = "retro-mail"; quantity = 2 } ];
      budget = None;
    }
  in
  run ~react:(mart_screen ~menu_ms) (fun () -> Mart.run ~log stock plan)

(* As mGBA showed it (mg-01, 2026-11-23): the prize list, a selection box
   too, stays up after A on ABRA until "So, you want the ABRA?" has printed
   (0.9 s), then YES/NO shows; an A on YES then gives the prize, and anything
   else declines it. *)
let redeem_list_lingers () =
  let a_count = ref 0 and question_at = ref max_int and taken = ref false in
  let react screen (p : S.press) =
    let show d s = S.show screen ~at_ms:(p.at_ms + d) s in
    if a p then (
      incr a_count;
      match !a_count with
      | 1 -> show 200 S.Dialog
      | 2 -> show 600 S.Question
      | 3 ->
          question_at := p.at_ms + 900;
          show 300 S.Dialog;
          show 900 S.Question
      | _ when p.at_ms >= !question_at && not !taken ->
          taken := true;
          show 100 S.Dialog;
          show 2000 S.Overworld
      | _ -> ())
  in
  let screen = S.create ~react () in
  let result =
    S.run screen (fun () ->
        Menu_input.run (fun () -> Game_corner.redeem_prize_mon ~log 0))
  in
  Printf.sprintf "%s; %s" (outcome result)
    (if !taken then "the prize taken" else "the prize declined")

(* The plan's answer event: its own A starts the talk (Bill's "Ready to set
   sail?" in the Cinnabar Center), YES or NO, then the settle. B turns a page
   as A does. *)
let answer ~yes () =
  let answered = ref "none" in
  let react screen (p : S.press) =
    let on_question = S.screen_at screen p.at_ms = S.Question in
    match p.buttons with
    | [ Wire.B ] when S.screen_at screen p.at_ms = S.Dialog_arrow ->
        talk ~page:true ~after_ms:1500 screen { p with buttons = [ Wire.A ] }
    | [ Wire.B ] when on_question && !answered = "none" ->
        answered := "NO";
        S.show screen ~at_ms:(p.at_ms + 100) S.Dialog;
        S.show screen ~at_ms:(p.at_ms + 1600) S.Overworld
    | [ Wire.A ] when on_question && !answered = "none" ->
        answered := "YES";
        talk ~page:true ~after_ms:1500 screen p
    | _ -> talk ~page:true ~after_ms:1500 screen p
  in
  let screen = S.create ~react () in
  let result = S.run screen (Talk.answer ~log ~yes) in
  Printf.sprintf "%s; %s; answered %s" (outcome result) (S.presses_text screen)
    !answered

(* A key item's row shows no count; any other's is read. *)
let found_count pocket read =
  Option.fold ~none:"none" ~some:string_of_int
    (Bag_items.found_count pocket (fun () -> read))

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "menu_actions"
    [
      case "mart: BUY and the row once the clerk's box and list take them"
        (mart_buy ~menu_ms:1500) "ok; A x2, down, A, up, A x2, B x6";
      case "heal: A to her text, A mashed 8 s, B mashed 5 s, the settle" heal
        "ok; A x26, B x20";
      case "heal: a Yes/No box the question reader misses still heals"
        heal_unread_question "ok; overworld";
      case "heal: no text box after A fails" heal_no_dialog
        "failed heal_no_dialog: the nurse's text did not show; A x20";
      case "save: START, down to SAVE, YES, saved, START and B to confirm" save
        "ok; Start, down x3, A x2, Start, B";
      case "cut: the turn, A, the page, YES" cut "ok; up, A x3, B x6, up";
      case "redeem: the page, Abra's row, YES" redeem "ok; A x4, B x6";
      case "redeem: YES once the question has replaced the prize list"
        redeem_list_lingers "ok; the prize taken";
      case "redeem: the clerk's blue arrow unread, the page turned by time"
        (redeem ~page:S.Dialog) "ok; A x4, B x6";
      case
        "cut: YES once the question takes input (mg-02 testing run 4: an A on \
         its first frame was dropped, the settle's B answered NO)"
        cut_slow_question "ok; up, A x3; answered YES";
      case
        "a page that took the first A as a hurry gets another (mg-02 testing \
         run 10: Elyssa's question)"
        slow_page "ok; A x4";
      case "berry numbers in the pouch: the fork's Leppa 6, Oran 7, Sitrus 10"
        (fun () ->
          List.map
            (fun b ->
              Option.fold ~none:"none" ~some:string_of_int
                (Berry_pouch.berry_number b))
            [ "leppa-berry"; "oran-berry"; "sitrus-berry"; "retro-mail" ]
          |> String.concat " ")
        "6 7 10 none";
      case "verify_mail_glitch: MIMIEN shows the held-item mark after Recycle"
        (verify S.Party_after_recycle)
        "ok; Start, A, B x6";
      case "verify_mail_glitch: MIMIEN still shows mail (Knock Off missed)"
        (verify (S.Party 1))
        "failed mail_glitch_not_active: mr-mime (slot 3) shows mail, not a \
         held item icon, after Recycle; Start, A, B x6";
      case "party swap: slot 1, SWITCH, slot 4" (swap 1 4)
        "ok; Start, A x2, down, A, down x3, A, B x6";
      case
        "party swap after a load on the Pokédex row, the menu slow to take \
         taps (live run t1): read down to POKéMON"
        (swap ~start_row:0 ~input_delay_ms:150 1 4)
        "ok; Start, down x2, A x2, down x2, A, down x4, A, B x6";
      case
        "party swap with the party's cursor left on slot 5 and the party slow \
         to take taps (live run t5): 6 with 1"
        (swap ~slot:5 ~input_delay_ms:150 6 1)
        "ok; Start, A, down x2, A, down x2, A, up x6, A, B x6";
      case
        "give to slot 1, already selected: the A waits for the party to take \
         input (mg-06 testing run 2)"
        give_to_slot_one "ok; A; ends on dialog arrow";
      case "USE on an item's menu: the A waits for the menu to take it"
        use_from_item_menu "ok; A; ends on black";
      case "trade: YES, slot 3, A through the trade" trade
        "ok; A x2, down x2, A x6, B x7";
      case
        "trade: a white box for a frame in the scene's fade is not the \
         trader's text"
        trade_fade "ok; A x2, down x2, A x4, B x7";
      case
        "trade on console B: the last page's A takes YES as the box draws, the \
         party shows (mg-02 testing 2026-11-24)"
        trade_yes_taken "ok; A x3, down x2, A x6, B x7";
      case
        "cut on console B: the last page's A takes YES as the box draws, the \
         Cut runs"
        cut_yes_taken "ok; up, A x3, B x5, up";
      case "answer YES: A to the person, the page, YES, the settle"
        (answer ~yes:true) "ok; A x3, B x6; answered YES";
      case "answer NO: the talk, whose B answers NO" (answer ~yes:false)
        "ok; A, B x8; answered NO";
      case "a key item found counts one, whatever its row reads"
        (fun () -> found_count Frlg_readers.Bag_screen.Key_items None)
        "1";
      case "an item found counts what its row reads"
        (fun () -> found_count Frlg_readers.Bag_screen.Items (Some 7))
        "7";
      case "spin: a battle in the first batch" (spin ~after_ms:1500)
        "ok; 12 turns";
      case "spin: no battle in two batches" (spin ~after_ms:100000)
        "failed no_encounter: no wild battle in 2 batches; 48 turns";
    ]
