open Frlg_readers

(* The fork's MailGlitchBattle taps: held 140 ms, 260 ms before the next. *)
let tap_hold_ms = 140
let tap_gap_ms = 260

(* The bag's pocket list climbs a row per short tap. *)
let scroll_hold_ms = 50
let scroll_gap_ms = 50

(* The Items pocket holds 42 kinds of item (pokefirered BAG_ITEMS_COUNT): this
   many UPs reach its top from any row. *)
let pocket_top_taps = 42

(* How long a screen may take to show after a press: a menu, the party list's
   slide-in, the move list's fade (the fork's 5 s MOVE_LIST_TIMEOUT). *)
let menu_timeout_ms = 3000
let list_timeout_ms = 5000

(* A move with a target cursor keeps the move menu up; one without leaves it at
   once. *)
let target_cursor_ms = 700
let look_every_ms = 250

(* The summary screen's moves page, where the move to forget is chosen. *)
let moves_page = 3

let tap_all ?(hold_ms = tap_hold_ms) ?(cooldown_ms = tap_gap_ms) buttons =
  let tap b = Wire.Press { buttons = [ b ]; hold_ms; cooldown_ms } in
  ignore (Effects.submit (List.map tap buttons) : Wire.batch_done)

let wait ms =
  ignore (Effects.submit [ Wire.Wait { wait_ms = ms } ] : Wire.batch_done)

let shows ?(timeout_ms = menu_timeout_ms) pred =
  match Effects.await ~timeout_ms pred with
  | Effects.Holds _ -> true
  | Effects.Timeout -> false

let move_menu_gone m = not (Battle_screen.move_menu m)

let target_chosen target : Battle_driver.move_result =
  tap_all (Battle_cursor.target target @ [ Wire.A ]);
  if shows move_menu_gone then Chosen
  else Not_done "the move menu stayed up after the target"

let choose_target target : Battle_driver.move_result =
  if shows ~timeout_ms:target_cursor_ms move_menu_gone then Chosen
  else target_chosen target

let other_name read_move_name ~slot ~expect =
  match (read_move_name, expect, Effects.read ()) with
  | Some read, Some want, Some m -> (
      match read m ~slot with
      | Some name when name <> want -> Some name
      | _ -> None)
  | _ -> None

(* On the move menu: to [slot], then A unless its PP shows none left; then B
   goes back to the action menu, as the game would after "There's no PP left
   for this move!". *)
let choose_move ~slot ~target : Battle_driver.move_result =
  tap_all (Battle_cursor.move ~slot);
  match Effects.read () with
  | Some m when Move_pp.no_pp_left m ->
      tap_all [ Wire.B ];
      Refused
  | _ ->
      tap_all [ Wire.A ];
      choose_target target

let use_move read_move_name ~slot ~target ~expect : Battle_driver.move_result =
  tap_all Battle_cursor.fight;
  if not (shows Battle_screen.move_menu) then
    Not_done "FIGHT did not open the move menu"
  else
    match other_name read_move_name ~slot ~expect with
    | Some name ->
        tap_all [ Wire.B ];
        Other_move name
    | None -> choose_move ~slot ~target

(* On the party list: the cursor read down (or up) to [slot] (from 0; the list
   keeps no row, but it drops taps while it slides in), A, and SHIFT at the top
   of the member's menu; done once the battle shows again. *)
let send_in ~slot =
  match
    Frlg_menu_cursor.Cursor_steps.step_to ~timeout_ms:list_timeout_ms
      ~tap:(fun b -> tap_all [ b ])
      Party_menu.selected_slot (slot + 1)
  with
  | Reached ->
      tap_all Wire.[ A; A ];
      shows ~timeout_ms:list_timeout_ms Battle_screen.battle_shows
  | Unread | Stuck _ -> false

let switch_to ~slot =
  tap_all Battle_cursor.pokemon;
  if not (shows ~timeout_ms:list_timeout_ms Party_menu.party_menu) then false
  else if send_in ~slot then true
  else (
    (* A message ("already in battle") then the list: B through both. *)
    tap_all Wire.[ B; B ];
    false)

let pocket_index : Bag_screen.pocket -> int = function
  | Items -> 0
  | Key_items -> 1
  | Poke_balls -> 2

let turn_to pocket =
  match Option.bind (Effects.read ()) Bag_screen.pocket with
  | None -> false
  | Some now ->
      let d = pocket_index pocket - pocket_index now in
      tap_all
        (List.init (abs d) (fun _ -> if d > 0 then Wire.Right else Wire.Left));
      shows (fun m -> Bag_screen.pocket m = Some pocket)

let pick_slot = function
  | None -> true
  | Some slot ->
      shows ~timeout_ms:list_timeout_ms Party_menu.party_menu
      &&
      (tap_all (Battle_cursor.down slot @ [ Wire.A ]);
       true)

let use_item (item : Battle_driver.item) =
  tap_all Battle_cursor.bag;
  shows ~timeout_ms:list_timeout_ms Bag_screen.bag_open
  && turn_to item.pocket
  && (tap_all ~hold_ms:scroll_hold_ms ~cooldown_ms:scroll_gap_ms
        (List.init pocket_top_taps (fun _ -> Wire.Up));
      (* A on the item, then USE at the top of its menu. *)
      tap_all (Battle_cursor.down item.row @ Wire.[ A; A ]);
      pick_slot item.on_slot)
  && shows ~timeout_ms:list_timeout_ms Battle_screen.battle_shows

let move_list m = Summary_screen.page m = Some moves_page
let cursor_read m = Move_list_cursor.row m <> None

(* "Stop learning ...?" comes after a NO or a list left without a choice;
   YES (A, where its cursor starts) stops, NO (B) asks "Delete a move?" again.
   [Unread] when it never shows. *)
let stop_prompt_ms = 8000

let answer_stop_learning button ~then_ : Battle_driver.learned =
  ignore (shows (fun m -> not (Battle_yes_no.yes_no_box m)) : bool);
  if shows ~timeout_ms:stop_prompt_ms Battle_yes_no.yes_no_box then (
    tap_all [ button ];
    then_)
  else Unread "no \"Stop learning?\" after the move list"

(* B leaves the list; the game asks "Stop learning ...?". A B the list does
   not take (mGBA, Victory Road, mg-04 testing 14: one tap 1.5 s after the
   list read, and the list stayed up for good) is tapped again while the list
   still shows, at most [leave_list_taps] times: B on the list only leaves
   it. *)
let leave_list_taps = 3
let list_left_ms = 1500

let rec tap_off_list taps =
  tap_all [ Wire.B ];
  if
    taps > 1
    && not (shows ~timeout_ms:list_left_ms (fun m -> not (move_list m)))
  then tap_off_list (taps - 1)

let leave_list button ~then_ =
  tap_off_list leave_list_taps;
  answer_stop_learning button ~then_

(* On the list, on its top row: down to [slot], A only with the cursor read
   there. *)
let pick slot ~move : Battle_driver.learned =
  tap_all (Battle_cursor.down slot);
  if shows (fun m -> Move_list_cursor.row m = Some slot) then (
    tap_all [ Wire.A ];
    Learned { slot; move })
  else
    leave_list Wire.B
      ~then_:(Unread (Printf.sprintf "the cursor did not read on move %d" slot))

let open_list () =
  tap_all [ Wire.A ];
  shows ~timeout_ms:list_timeout_ms (fun m -> move_list m && cursor_read m)

let forget_for read_offered ~move ~slot : Battle_driver.learned =
  match read_offered () with
  | Some offered when offered = move -> pick slot ~move:(Some offered)
  | Some offered ->
      leave_list Wire.A ~then_:(Not_learned { offered = Some offered })
  | None -> leave_list Wire.B ~then_:(Unread "the move offered did not read")

let no_list = Battle_driver.Unread "the list to forget from did not show"

let answer_move_learn read_offered (learn : Battle_driver.learn) :
    Battle_driver.learned =
  match learn with
  | Keep_moves ->
      tap_all [ Wire.B ];
      answer_stop_learning Wire.A ~then_:(Not_learned { offered = None })
  | Forget slot -> if open_list () then pick slot ~move:None else no_list
  | Forget_for { move; slot } ->
      if open_list () then forget_for read_offered ~move ~slot else no_list

let answer_use_next yes = tap_all [ (if yes then Wire.A else Wire.B) ]

(* Carries out a look's answer: [Some event] ends [next_event]. *)
let carry_out : Event_rule.step -> Battle_driver.event option = function
  | Report event -> Some event
  | Press button ->
      tap_all [ button ];
      None
  | Look ->
      wait look_every_ms;
      None

let look_once state =
  match Effects.read () with
  | None ->
      wait look_every_ms;
      (state, None)
  | Some m ->
      let facts = Battle_look.of_measurements m in
      let state, step = Event_rule.next state facts ~at_ms:m.t_ms in
      (state, carry_out step)

let next_event ~timeout_ms =
  let deadline = Effects.now () +. float_of_int timeout_ms in
  let rec loop state =
    if Effects.now () > deadline then Battle_driver.Timed_out
    else
      match look_once state with
      | _, Some event -> event
      | state, None -> loop state
  in
  loop (Event_rule.start ~at_ms:(Effects.now ()))

(* RUN, then the menu gone ("Got away safely!" or a refusal's text), so the
   next look does not take the menu RUN was chosen on for the next one; a menu
   still up means the press was lost, and the next look gets RUN again. *)
let run () =
  tap_all Battle_cursor.run_away;
  ignore (shows (fun m -> not (Battle_screen.battle_menu m)) : bool)

let no_reader () = None

let make ?read_move_name ?(read_offered_move = no_reader) () : Battle_driver.t =
  {
    next_event;
    use_move = use_move read_move_name;
    switch_to;
    send_in;
    run;
    use_item;
    answer_move_learn = answer_move_learn read_offered_move;
    answer_use_next;
  }
