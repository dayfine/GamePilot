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
   slide-in, the bag's fade. *)
let menu_timeout_ms = 3000
let list_timeout_ms = 5000

(* A move with a target cursor keeps the move menu up; one without leaves it at
   once. *)
let target_cursor_ms = 700
let look_every_ms = 250

let tap_all ?(hold_ms = tap_hold_ms) ?(cooldown_ms = tap_gap_ms) buttons =
  let tap b = Wire.press ~hold_ms ~cooldown_ms [ b ] in
  ignore (Effects.submit (List.map tap buttons) : Wire.batch_done)

let wait ms =
  ignore (Effects.submit [ Wire.Wait { wait_ms = ms } ] : Wire.batch_done)

let shows ?(timeout_ms = menu_timeout_ms) pred =
  match Effects.await ~timeout_ms pred with
  | Effects.Holds _ -> true
  | Effects.Timeout -> false

let move_menu_gone m = not (Battle_screen.move_menu m)

let target_chosen target : Battle.move_result =
  tap_all (Battle_cursor.target target @ [ Wire.A ]);
  if shows move_menu_gone then Chosen
  else Not_done "the move menu stayed up after the target"

let choose_target target : Battle.move_result =
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
let choose_move ~slot ~target : Battle.move_result =
  tap_all (Battle_cursor.move ~slot);
  match Effects.read () with
  | Some m when Move_pp.no_pp_left m ->
      tap_all [ Wire.B ];
      Refused
  | _ ->
      tap_all [ Wire.A ];
      choose_target target

let use_move read_move_name ~slot ~target ~expect : Battle.move_result =
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

(* Back from a refused switch: B through a message ("already in battle", "has
   no energy left to battle!") and the list, then B again while the action
   menu does not show, at most [back_taps] times, so the next look does
   not take the list for one the game opened. *)
let back_taps = 3

let rec back_to_action_menu taps =
  if taps > 0 && not (shows Battle_screen.battle_menu) then (
    tap_all [ Wire.B ];
    back_to_action_menu (taps - 1))

let switch_to ~slot =
  tap_all Battle_cursor.pokemon;
  if not (shows ~timeout_ms:list_timeout_ms Party_menu.party_menu) then false
  else if send_in ~slot then true
  else (
    tap_all Wire.[ B; B ];
    back_to_action_menu back_taps;
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

let use_item (item : Battle.item) =
  tap_all Battle_cursor.bag;
  shows ~timeout_ms:list_timeout_ms Bag_screen.bag_open
  && turn_to item.pocket
  && (tap_all ~hold_ms:scroll_hold_ms ~cooldown_ms:scroll_gap_ms
        (List.init pocket_top_taps (fun _ -> Wire.Up));
      (* A on the item, then USE at the top of its menu. *)
      tap_all (Battle_cursor.down item.row @ Wire.[ A; A ]);
      pick_slot item.on_slot)
  && shows ~timeout_ms:list_timeout_ms Battle_screen.battle_shows

let answer_use_next yes = tap_all [ (if yes then Wire.A else Wire.B) ]

(* Carries out a look's answer: [Some event] ends [next_event]. *)
let carry_out : Event_rule.step -> Battle.event option = function
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

(* A move learn's YES/NO may be a trainer's switch offer: its text says. *)
let told_apart is_switch_offer : Battle.event -> Battle.event = function
  | Move_learn when is_switch_offer () -> Switch_offer
  | event -> event

let next_event is_switch_offer seen_battle leveled_up ~timeout_ms =
  let deadline = Effects.now () +. float_of_int timeout_ms in
  let rec loop state =
    if Effects.now () > deadline then Battle.Timed_out
    else
      match look_once state with
      | state, Some event ->
          seen_battle := Event_rule.seen_battle state;
          leveled_up := Event_rule.leveled_up state;
          told_apart is_switch_offer event
      | state, None -> loop state
  in
  loop
    (Event_rule.resume ~seen_battle:!seen_battle ~leveled_up:!leveled_up
       ~at_ms:(Effects.now ()))

(* RUN, then the menu gone ("Got away safely!" or a refusal's text), so the
   next look does not take the menu RUN was chosen on for the next one; a menu
   still up means the press was lost, and the next look gets RUN again. *)
let run () =
  tap_all Battle_cursor.run_away;
  ignore (shows (fun m -> not (Battle_screen.battle_menu m)) : bool)

let never () = false

let make ?read_move_name ?read_forget_list ?(is_switch_offer = never) ?log () :
    Battle.game_steps =
  let seen_battle = ref false in
  let leveled_up = ref false in
  {
    next_event = next_event is_switch_offer seen_battle leveled_up;
    use_move = use_move read_move_name;
    switch_to;
    send_in;
    run;
    use_item;
    level_up =
      Battle_level_up_steps.make ?read_forget_list ~is_switch_offer ?log ();
    answer_use_next;
  }
