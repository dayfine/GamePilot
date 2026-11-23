(* The shared actions' flows on a scripted screen read through the FRLG
   readers from recorded frames (Scripted_screen): what each presses, and
   that each waits on the screen it needs. *)

open Frlg_actions
open Frlg_overworld_fixtures
module S = Scripted_screen

let outcome = function
  | Ok () -> "ok"
  | Error cause -> "failed " ^ Story.Failure.cause_to_string cause

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

let heal_no_question () =
  run
    ~react:(fun screen p ->
      if a p then S.show screen ~at_ms:(p.at_ms + 200) S.Dialog)
    (Heal_and_save.heal_at_nurse ~log)

(* START opens the menu on row 1; A on SAVE asks. *)
let save_screen screen (p : S.press) =
  if p.buttons = [ Wire.Start ] then
    S.show screen ~at_ms:(p.at_ms + 100) (S.Start_menu 1)
  else talk ~page:false ~after_ms:2000 screen p

let save () = run ~react:save_screen (Heal_and_save.save ~log)

let cut () =
  run ~react:(talk ~page:true ~after_ms:1500) (fun () ->
      Cut_tree.cut ~log Grid_maps.Direction.North)

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
let redeem () =
  run
    ~react:
      (on_each_a
         [
           [ (200, S.Dialog_arrow) ];
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

let trade () =
  run ~react:trade_screen (fun () -> Ingame_trade.trade ~log ~slot:3)

(* A wild battle starts [after_ms] into the spin. *)
let spin ~after_ms () =
  run_on
    (fun screen -> Printf.sprintf "%d turns" (List.length screen.S.presses))
    ~react:(fun screen p ->
      if p.index = 0 then S.show screen ~at_ms:(p.at_ms + after_ms) S.Battle)
    (fun () -> Spin_for_encounter.spin ~log ~facing:North ~max_batches:2)

(* The clerk's text box shows 200 ms after A; its BUY/SELL box takes an A only
   [menu_ms] later (no reader: the text box), which opens the BUY list; B on
   the list closes the Mart. *)
let mart_screen ~menu_ms =
  let text_at = ref max_int in
  fun screen (p : S.press) ->
    let show d s = S.show screen ~at_ms:(p.at_ms + d) s in
    match (p.buttons, S.screen_at screen p.at_ms) with
    | [ Wire.A ], S.Overworld ->
        text_at := p.at_ms + 200;
        show 200 S.Dialog
    | [ Wire.A ], S.Dialog when p.at_ms >= !text_at + menu_ms ->
        show 300 S.Mart_list
    | [ Wire.B ], S.Mart_list -> show 300 S.Overworld
    | _ -> ()

let mart_open ~menu_ms () =
  let plan = { Mart_plan.map = "test"; lines = []; budget = None } in
  run ~react:(mart_screen ~menu_ms) (fun () -> Mart.run ~log [] plan)

let case name input expectation = { Case_table.name; input; expectation }

let () =
  Case_table.run "menu_actions"
    [
      case "mart: A on BUY once the clerk's box takes it"
        (mart_open ~menu_ms:1500) "ok; A x2, B x6";
      case "heal: a page, YES, the healing, back" heal "ok; A x3, B x8";
      case "heal: a text box with no question fails" heal_no_question
        "failed heal_no_question: the nurse's question did not show; A";
      case "save: START, down to SAVE, YES, saved" save
        "ok; Start, down x3, A x2, B x5";
      case "cut: the turn, A, the page, YES" cut "ok; up, A x3, B x7";
      case "redeem: the page, Abra's row, YES" redeem "ok; A x4, B x7";
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
      case "trade: YES, slot 3, A through the trade" trade
        "ok; A x2, down x2, A x6, B x7";
      case "spin: a battle in the first batch" (spin ~after_ms:1500)
        "ok; 12 turns";
      case "spin: no battle in two batches" (spin ~after_ms:100000)
        "failed no_encounter: no wild battle in 2 batches; 48 turns";
    ]
