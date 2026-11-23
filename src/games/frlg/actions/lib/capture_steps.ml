open Frlg_readers
module B = Frlg_battle
module M = Menu_input
module Text = Frlg_text

let throw_poll_ms = 500
let throw_timeout_ms = 60000
let finish_quiet_ms = 5000
let finish_timeout_ms = 30000
let presses_per_check = 4

(* The fork's taps here: 160 ms held, then 640 ms (throw) or 340 ms (B). *)
let throw_press_ms = 640

(* A on USE until the battle's text box is back: the fork presses it once, but
   on mGBA the USE menu sometimes drops that A (mg-02 testing run 11: nine
   "throws" in a row left the bag open, its ball not thrown). *)
let use_presses = 4
let mash_release_ms = 340
let opening_timeout_ms = 15000

let wait ms =
  ignore (Effects.submit [ Wire.Wait { wait_ms = ms } ] : Wire.batch_done)

let menu_tap = M.hold ~hold_ms:M.tap_hold_ms ~cooldown_ms:M.tap_release_ms

let tap buttons =
  ignore (Effects.submit (List.map menu_tap buttons) : Wire.batch_done)

let find_encounter ~log ~facing ~max_batches () =
  match Spin_for_encounter.spin ~log ~facing:(facing ()) ~max_batches with
  | () -> true
  | exception M.Action_failed _ -> false

let opening_line species =
  "Wild " ^ String.uppercase_ascii species ^ " appeared!"

let line = Text.Text_lines.battle_message 0

let reads_opening candidate m =
  match Text.Line_reading.pick line [ candidate ] m with
  | Read _ -> true
  | No_match _ -> false

(* The opening message's line has been printed, or passed. *)
let opening_over m =
  Battle_text_arrow.advance_arrow m || Battle_screen.battle_menu m

let await_opening reads =
  let awaited =
    Effects.await ~timeout_ms:opening_timeout_ms (fun m ->
        reads m || opening_over m)
  in
  match awaited with Holds m -> reads m | Timeout -> false

(* The opening message's line once it reads, its page waits (the arrow) or the
   action menu shows: whichever comes first. *)
let read_opening ~target =
  let candidate = opening_line target in
  let probes =
    Text.Line_reading.probes ~ink:Text.Line_reading.light_ink
      (Text_data.glyphs ()) line [ candidate ]
  in
  if
    Effects.with_probes probes (fun () ->
        await_opening (reads_opening candidate))
  then Some target
  else None

let read_encounter ~target (driver : B.Battle_driver.t) () =
  let seen = read_opening ~target in
  match driver.next_event ~timeout_ms:B.Wild_flee.event_timeout_ms with
  | Action_menu -> seen
  | event ->
      M.fail "capture_no_menu"
        ("the wild battle's action menu did not show: "
        ^ B.Battle_driver.event_name event)

let flee ~log driver () =
  match B.Wild_flee.run driver ~log with
  | Fled _ -> true
  | Not_fled why ->
      log ("Capture: " ^ why);
      false

let press_b () = M.press ~cooldown_ms:mash_release_ms Wire.B

(* BAG, the Poke Balls pocket's top, the Poke Ball's row: false if the bag has
   none, after B back to the action menu (the fork mashes B 2 s). *)
let ball_chosen ~log () =
  tap B.Battle_cursor.bag;
  ignore (M.await_screen ~code:"no_bag" "the bag" Bag_screen.bag_open);
  Bag_items.pocket_top Poke_balls;
  match Bag_items.select "poke-ball" with
  | () -> true
  | exception M.Action_failed cause ->
      log ("Capture: no Poke Ball found in the bag: " ^ cause.detail);
      M.close "the bag" Bag_screen.bag_open;
      false

(* The fork's overworld_shows: START opens the start menu only on the
   overworld; B closes it again. *)
let start_menu_wait_ms = 1200
let start_menu_close_ms = 600

let overworld_shows () =
  M.press ~cooldown_ms:start_menu_wait_ms Wire.Start;
  match Effects.read () with
  | Some m when Start_menu.start_menu_open m ->
      M.press ~cooldown_ms:start_menu_close_ms Wire.B;
      true
  | Some _ | None -> false

(* After the throw: the nickname question ("Give a nickname ...?", its Yes/No
   arrow) or the overworld is a catch, the action menu is a break-free; every
   fourth look with neither checks the overworld, then presses B through the
   messages (wait_for_throw()). *)
let rec wait_for_throw ~deadline polls : Capture.throw_end =
  if Effects.now () >= deadline then Throw_failed
  else
    match Effects.read () with
    | Some m when Option.is_some (Dialog.yes_no_arrow m) -> Caught
    | Some m when Battle_screen.battle_menu m -> Broke_free
    | _ when polls mod presses_per_check <> 0 ->
        wait throw_poll_ms;
        wait_for_throw ~deadline (polls + 1)
    | _ when overworld_shows () -> Caught
    | _ ->
        press_b ();
        wait_for_throw ~deadline (polls + 1)

let throw_ball ~log () : Capture.throw_end =
  if not (ball_chosen ~log ()) then No_balls
  else (
    (* A on the ball, then USE at the top of its menu: the throw. *)
    M.press ~cooldown_ms:throw_press_ms Wire.A;
    M.press_until ~max_presses:use_presses ~code:"capture_no_throw" "the throw"
      Wire.A ~cooldown_ms:throw_press_ms Battle_screen.battle_text_box;
    Effects.with_probes Dialog.yes_no_probes (fun () ->
        wait_for_throw ~deadline:(Effects.now () +. float throw_timeout_ms) 1))

(* B, the fork's mash, until no battle screen has shown for [finish_quiet_ms]:
   it answers the nickname NO and turns the messages and the Pokedex page. *)
let rec mash_out ~deadline ~quiet_since =
  let now = Effects.now () in
  let battle =
    match Effects.read () with
    | Some m -> Battle_screen.battle_shows m || Battle_yes_no.yes_no_box m
    | None -> true
  in
  let quiet_since = if battle then now else quiet_since in
  if now -. quiet_since >= float finish_quiet_ms then true
  else if now >= deadline then false
  else (
    press_b ();
    mash_out ~deadline ~quiet_since)

let finish_catch ~log (destination : Capture.destination) =
  log
    ("Capture: no nickname; it goes to the "
    ^ (match destination with Party -> "party" | Pc -> "PC")
    ^ ".");
  let now = Effects.now () in
  mash_out ~deadline:(now +. float finish_timeout_ms) ~quiet_since:now
  &&
  (M.settle_back ~label:"after the catch" ~log;
   true)

let make ~log ~facing ~target ~max_spin_batches : Capture.rig =
  let driver = B.Screen_driver.make () in
  {
    find_encounter = find_encounter ~log ~facing ~max_batches:max_spin_batches;
    read_encounter = read_encounter ~target driver;
    flee = flee ~log driver;
    throw_ball = throw_ball ~log;
    finish_catch = finish_catch ~log;
    log;
  }
