open Frlg_readers

let tap_hold_ms = 140
let tap_gap_ms = 260
let look_ms = 250
let still_ms = 1500
let menu_timeout_ms = 3000
let list_timeout_ms = 5000
let stop_prompt_ms = 8000
let next_timeout_ms = 20_000
let evolution_hold_ms = 12_000
let evolution_timeout_ms = 30_000
let stats_presses = 3
let leave_list_taps = 3
let list_left_ms = 1500

let tap_all buttons =
  let tap b = Wire.press ~hold_ms:tap_hold_ms ~cooldown_ms:tap_gap_ms [ b ] in
  ignore (Effects.submit (List.map tap buttons) : Wire.batch_done)

let shows ~timeout_ms pred =
  match Effects.await ~timeout_ms pred with
  | Effects.Holds _ -> true
  | Effects.Timeout -> false

let gone ~timeout_ms pred = shows ~timeout_ms (fun m -> not (pred m))

let battle : Level_up_screens.context =
  {
    stats = Battle_screen.level_up_box;
    question = Battle_yes_no.yes_no_box;
    back = (fun m -> Battle_screen.battle_menu m || Party_menu.party_menu m);
  }

let forget_list = Level_up_screens.forget_list
let question = Battle_yes_no.yes_no_box
let arrow = Battle_text_arrow.advance_arrow
let classify = Level_up_screens.classify battle
let watched m = classify m <> None || arrow m
let press_a () = tap_all [ Wire.A ]

(* Page 1, page 2, then the stats window closes: A while it shows, at most one
   per page and one lost. *)
let rec through_stats presses =
  if presses > 0 && shows ~timeout_ms:look_ms Battle_screen.level_up_box then (
    press_a ();
    through_stats (presses - 1))

let timed_out started = Effects.now () -. started > float_of_int next_timeout_ms

type quiet = { quiet_since : float option; no_battle_since : float option }

let no_quiet = { quiet_since = None; no_battle_since = None }

let is_no_battle m =
  Battle_look.classify (Battle_look.of_measurements m) = Battle_look.No_battle

let since_or_now prev = Some (Option.value prev ~default:(Effects.now ()))

let elapsed_at_least ms = function
  | Some since -> Effects.now () -. since >= ms
  | None -> false

let classify_look is_switch_offer = function
  | Level_up.Move_prompt when is_switch_offer () -> Level_up.Back
  | Level_up.Stats who ->
      through_stats stats_presses;
      Level_up.Stats who
  | look -> look

let rec next_look is_switch_offer ~started q =
  if timed_out started then Level_up.Timed_out
  else
    match Effects.await ~timeout_ms:look_ms watched with
    | Holds m -> on_watched is_switch_offer m ~started
    | Timeout -> on_quiet is_switch_offer ~started q

and on_watched is_switch_offer m ~started =
  match classify m with
  | Some look -> classify_look is_switch_offer look
  | None ->
      press_a ();
      next_look is_switch_offer ~started no_quiet

and on_quiet is_switch_offer ~started q =
  match Effects.read () with
  | None -> next_look is_switch_offer ~started q
  | Some m -> step_quiet is_switch_offer m ~started q

and step_quiet is_switch_offer m ~started q =
  if is_no_battle m then
    let no_battle_since = since_or_now q.no_battle_since in
    if elapsed_at_least Event_rule.over_after_ms no_battle_since then
      Level_up.Back
    else
      next_look is_switch_offer ~started { quiet_since = None; no_battle_since }
  else if Battle_screen.battle_text_box m then
    let quiet_since = since_or_now q.quiet_since in
    if elapsed_at_least (float_of_int still_ms) quiet_since then (
      press_a ();
      next_look is_switch_offer ~started no_quiet)
    else
      next_look is_switch_offer ~started { quiet_since; no_battle_since = None }
  else next_look is_switch_offer ~started no_quiet

let next is_switch_offer () =
  next_look is_switch_offer ~started:(Effects.now ()) no_quiet

let open_list () =
  press_a ();
  let deadline = Effects.now () +. float_of_int list_timeout_ms in
  let rec on_until () =
    if Effects.now () > deadline then false
    else
      match
        Effects.await ~timeout_ms:look_ms (fun m -> forget_list m || arrow m)
      with
      | Holds m when forget_list m -> true
      | Holds _ ->
          press_a ();
          on_until ()
      | Timeout -> on_until ()
  in
  on_until ()

let forget row =
  tap_all (Battle_cursor.down row);
  if
    shows ~timeout_ms:menu_timeout_ms (fun m ->
        Move_list_cursor.row m = Some row)
  then (
    press_a ();
    gone ~timeout_ms:list_timeout_ms forget_list)
  else false

(* "Stop learning ...?" after a NO or a list left: its box clears, returns,
   and YES (A, where its cursor starts) stops. *)
let stop_learning () =
  ignore (gone ~timeout_ms:menu_timeout_ms question : bool);
  if shows ~timeout_ms:stop_prompt_ms question then (
    press_a ();
    gone ~timeout_ms:menu_timeout_ms question)
  else false

(* B leaves the list; a B it does not take (mGBA, Victory Road, mg-04 testing
   14) is tapped again while the list still shows. *)
let rec leave_list_after taps =
  tap_all [ Wire.B ];
  if gone ~timeout_ms:list_left_ms forget_list then stop_learning ()
  else taps > 1 && leave_list_after (taps - 1)

let leave_list () = leave_list_after leave_list_taps

let decline () =
  tap_all [ Wire.B ];
  stop_learning ()

let not_evolving m = not (Evolution_screen.evolution_shows m)
let scene_goes_on m = question m || forget_list m || arrow m

let evolution ~cancel : Level_up.scene =
  if cancel then
    ignore
      (Effects.submit
         [ Wire.press ~hold_ms:evolution_hold_ms ~cooldown_ms:0 [ Wire.B ] ]
        : Wire.batch_done);
  match Effects.await ~timeout_ms:evolution_timeout_ms not_evolving with
  | Holds m when scene_goes_on m -> Continues
  | Holds _ | Timeout -> Ended

let empty_list () : Level_up.forget_list = { offered = None; known = [] }
let never () = false

let make ?(read_forget_list = empty_list) ?(is_switch_offer = never)
    ?(log = ignore) () : Level_up.game_steps =
  {
    next = next is_switch_offer;
    open_list;
    read_list = read_forget_list;
    forget;
    leave_list;
    decline;
    evolution;
    log;
  }
