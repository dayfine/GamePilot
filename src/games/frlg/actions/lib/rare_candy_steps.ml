open Frlg_readers
module M = Menu_input

let candy = "rare-candy"
let use_row = 0

let probes =
  Party_dialogs.probes @ Frlg_battle.Battle_look.probes @ Dialog.probes

let known_moves = 4
let look_ms = 250
let still_ms = 1500
let page_press_ms = 600
let next_timeout_ms = 20_000
let list_timeout_ms = 8000
let question_ms = 8000
let evolution_hold_ms = 12_000
let evolution_timeout_ms = 30_000

(* The list to forget from: the summary's moves page with its cursor. *)
let forget_list m =
  Summary_screen.page m = Some Summary_moves.moves_page
  && Move_list_cursor.row m <> None

let question m = Party_dialogs.move_learn_box m || Battle_yes_no.yes_no_box m
let in_bag m = Bag_screen.bag_open m && not (Bag_screen.item_menu m)

let classify m : Level_up.look option =
  if forget_list m then Some Forget_list
  else if question m then Some Move_prompt
  else if Party_dialogs.level_up_box m then Some Stats
  else if in_bag m then Some Back
  else if Evolution_screen.evolution_shows m then Some Evolving
  else None

let arrow m = Dialog.advance_arrow m || Battle_text_arrow.advance_arrow m
let watched m = classify m <> None || arrow m
let press_a () = M.press ~cooldown_ms:page_press_ms Wire.A

let open_candy ~log ~slot : Rare_candy.opened =
  match Bag_items.item_action candy use_row with
  | () ->
      ignore
        (M.await_screen ~code:"no_party" "the party to use it on"
           Party_menu.party_menu);
      Party_actions.choose_slot slot;
      Opened
  | exception M.Action_failed { Story.Failure.code = "not_in_bag"; _ } ->
      M.close "the bag" Bag_screen.bag_open;
      M.settle_back ~label:"no rare candy" ~log;
      No_candy
  | exception M.Action_failed c -> Not_opened (Story.Failure.cause_to_string c)

(* A message with no arrow ("... was elevated to Lv. 51.", "... learned
   ...!") waits for A once printed. A is pressed only after it has shown
   [still_ms] with no box: the last page of "Should a move be deleted ...?"
   has no arrow either, and an A as its YES/NO box draws would take YES. *)
let timed_out started = Effects.now () -. started > float_of_int next_timeout_ms

(* Where a quiet look has seen the same text box since, if it has. *)
let still_since m ~quiet_since =
  if not (Dialog.dialog_up m) then None
  else Some (Option.value quiet_since ~default:(Effects.now ()))

let rec next_look ~started ~quiet_since =
  if timed_out started then Level_up.Timed_out
  else
    match Effects.await ~timeout_ms:look_ms watched with
    | Holds m -> on_look m ~started
    | Timeout -> quiet ~started ~quiet_since

and on_look m ~started =
  match classify m with
  | Some look -> look
  | None ->
      press_a ();
      next_look ~started ~quiet_since:None

and quiet ~started ~quiet_since =
  match Option.bind (Effects.read ()) (still_since ~quiet_since) with
  | Some since when Effects.now () -. since > float_of_int still_ms ->
      press_a ();
      next_look ~started ~quiet_since:None
  | since -> next_look ~started ~quiet_since:since

let shows ~timeout_ms pred =
  match Effects.await ~timeout_ms pred with
  | Effects.Holds _ -> true
  | Timeout -> false

(* Page 1, page 2, then the window closes: A while it shows, at most one per
   page and one lost. *)
let stats_presses = 3

let rec through_stats presses =
  if presses > 0 && shows ~timeout_ms:look_ms Party_dialogs.level_up_box then (
    press_a ();
    through_stats (presses - 1))

let next () =
  match next_look ~started:(Effects.now ()) ~quiet_since:None with
  | Stats ->
      through_stats stats_presses;
      Level_up.Stats
  | look -> look

(* YES (the box's cursor starts there); the party then prints "Which move
   should be forgotten?" and waits for A, the evolution scene fades to the
   list at once. *)
let open_list () =
  M.press ~cooldown_ms:page_press_ms Wire.A;
  let rec on_until deadline =
    if Effects.now () > deadline then false
    else
      match
        Effects.await ~timeout_ms:look_ms (fun m -> forget_list m || arrow m)
      with
      | Holds m when forget_list m -> true
      | Holds _ ->
          press_a ();
          on_until deadline
      | Timeout -> on_until deadline
  in
  on_until (Effects.now () +. float_of_int list_timeout_ms)

let read_list () : Level_up.forget_list =
  {
    offered = Summary_moves.read_offered ();
    known = List.init known_moves Summary_moves.read_row;
  }

(* After the A that answers, the next look must not find the same screen
   still fading out: the list, or the box, has to go first. *)
let gone ~timeout_ms pred = shows ~timeout_ms (fun m -> not (pred m))

let forget row =
  M.taps Wire.Down row;
  if
    shows ~timeout_ms:M.screen_timeout_ms (fun m ->
        Move_list_cursor.row m = Some row)
  then (
    M.press ~cooldown_ms:page_press_ms Wire.A;
    gone ~timeout_ms:list_timeout_ms forget_list)
  else false

(* "Stop trying to teach ...?" after a NO or a list left: its box goes, comes
   back, and YES (A, where its cursor starts) stops. *)
let stop_teaching () =
  ignore (gone ~timeout_ms:M.screen_timeout_ms question);
  if shows ~timeout_ms:question_ms question then (
    M.press ~cooldown_ms:page_press_ms Wire.A;
    gone ~timeout_ms:M.screen_timeout_ms question)
  else false

(* B on the list only leaves it; a B it does not take (Screen_driver's
   leave_list, mGBA, mg-04 testing 14) is tapped again. *)
let leave_taps = 3
let list_left_ms = 1500

let rec leave_list_after taps =
  M.press Wire.B;
  if shows ~timeout_ms:list_left_ms (fun m -> not (forget_list m)) then
    stop_teaching ()
  else taps > 1 && leave_list_after (taps - 1)

let leave_list () = leave_list_after leave_taps

let decline () =
  M.press ~cooldown_ms:page_press_ms Wire.B;
  stop_teaching ()

let not_evolving m = not (Evolution_screen.evolution_shows m)

let evolution ~cancel =
  if cancel then
    ignore
      (Effects.submit
         [ M.hold ~hold_ms:evolution_hold_ms ~cooldown_ms:0 Wire.B ]);
  ignore (shows ~timeout_ms:evolution_timeout_ms not_evolving)

let close_bag ~log () =
  M.close "the bag" Bag_screen.bag_open;
  M.settle_back ~label:"rare candy" ~log

let level_up_rig ~log : Level_up.rig =
  { next; open_list; read_list; forget; leave_list; decline; evolution; log }

let make ~log : Rare_candy.rig =
  {
    open_candy = open_candy ~log;
    level_up = level_up_rig ~log;
    close_bag = close_bag ~log;
    log;
  }
