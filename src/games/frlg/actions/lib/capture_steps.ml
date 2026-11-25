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

(* The name as the game shows it, from pret's species_names.h: the slug
   uppercased is not it for NIDORAN♂, NIDORAN♀, MR. MIME or FARFETCH'D (mGBA,
   2026-11-25: Route 3's Nidoran never read). *)
let shown_name names species =
  match List.assoc_opt species names with
  | Some name -> name
  | None -> String.uppercase_ascii species

let opening_line names species =
  "Wild " ^ shown_name names species ^ " appeared!"

let line = Text.Text_lines.battle_message 0

(* The candidate the line shows, if any. *)
let reads_opening candidates m =
  match Text.Line_reading.pick line candidates m with
  | Read { text; _ } -> Some text
  | No_match _ -> None

(* The opening message's line has been printed, or passed. *)
let opening_over m =
  Battle_text_arrow.advance_arrow m || Battle_screen.battle_menu m

let await_opening reads =
  let awaited =
    Effects.await ~timeout_ms:opening_timeout_ms (fun m ->
        Option.is_some (reads m) || opening_over m)
  in
  match awaited with Holds m -> reads m | Timeout -> None

let opening_probes candidates =
  Text.Line_reading.probes ~ink:Text.Line_reading.light_ink
    (Text_data.glyphs ()) line candidates

(* The lines of these species, each with its slug. *)
let opening_lines species =
  let names = Text_data.species_names () in
  List.map (fun s -> (opening_line names s, s)) species

let any_species_ms = 1000

(* The species whose line the page shows, every species a candidate. *)
let read_page_species () =
  let lines = opening_lines (List.map fst (Text_data.species_names ())) in
  let candidates = List.map fst lines in
  let shown m = reads_opening candidates m in
  let awaited () =
    Effects.await ~timeout_ms:any_species_ms (fun m -> Option.is_some (shown m))
  in
  match Effects.with_probes (opening_probes candidates) awaited with
  | Holds m -> Option.bind (shown m) (fun text -> List.assoc_opt text lines)
  | Timeout -> None

(* The opening's page, waiting for its button, read with every species a
   candidate: a foe that is not one of the plan's (Route 3's Spearow and Pidgey)
   reads too. One look, not a watch while the line prints: hundreds of probes
   on every frame would slow the daemon. *)
let read_any_species () =
  match Effects.read () with
  | Some m when Battle_text_arrow.advance_arrow m -> read_page_species ()
  | Some _ | None -> None

(* The opening message's line once it reads, its page waits (the arrow) or the
   action menu shows: whichever comes first. A page that waits without the
   plan's species on it is read again for any species. *)
let read_opening species =
  let lines = opening_lines species in
  let candidates = List.map fst lines in
  match
    Effects.with_probes (opening_probes candidates) (fun () ->
        await_opening (reads_opening candidates))
  with
  | Some text -> List.assoc_opt text lines
  | None -> read_any_species ()

let mark_timeout_ms = 2000
let mark_measured m = Option.is_some (Caught_mark.read m)

let await_mark () =
  match Effects.await ~timeout_ms:mark_timeout_ms mark_measured with
  | Holds m -> Caught_mark.caught m
  | Timeout -> false

(* The caught mark on the action menu's frame, once its probes measure. *)
let read_mark () = Effects.with_probes Caught_mark.probes await_mark

let candidates : Capture_plan.target -> string list = function
  | Species s -> [ s ]
  | Uncaught l -> l

let read_encounter ~target (game_steps : B.Battle.game_steps) () :
    Capture.encounter =
  let species =
    match candidates target with [] -> None | l -> read_opening l
  in
  match game_steps.next_event ~timeout_ms:B.Wild_flee.event_timeout_ms with
  | Action_menu -> { species; caught = read_mark () }
  | event ->
      M.fail "capture_no_menu"
        ("the wild battle's action menu did not show: "
       ^ B.Battle.event_name event)

(* The pacing counts its taps: one lost to the battle's exit would put it a
   tile off, so the overworld settles first (wait_out_battle_exit()). *)
let flee ~log game_steps () =
  match B.Wild_flee.run game_steps ~log with
  | Fled _ ->
      M.settle_back ~label:"after the flee" ~log;
      true
  | Not_fled why ->
      log ("Capture: " ^ why);
      false

let press_b () = M.press ~cooldown_ms:mash_release_ms Wire.B

(* BAG, the Poke Balls pocket's top, the ball's row: false if the bag has none,
   after B back to the action menu (the fork mashes B 2 s). *)
let ball_chosen ~log ball () =
  tap B.Battle_cursor.bag;
  ignore (M.await_screen ~code:"no_bag" "the bag" Bag_screen.bag_open);
  Bag_items.pocket_top Poke_balls;
  match Bag_items.select ball with
  | () -> true
  | exception M.Action_failed cause ->
      log ("Capture: no " ^ ball ^ " found in the bag: " ^ cause.detail);
      M.close "the bag" Bag_screen.bag_open;
      false

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
    | _ when Pacing_steps.overworld_shows () -> Caught
    | _ ->
        press_b ();
        wait_for_throw ~deadline (polls + 1)

let throw_ball ~log ball () : Capture.throw_end =
  if not (ball_chosen ~log ball ()) then No_balls
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

let find_encounter ~log ~pace spot () =
  Pacing_steps.find_encounter ~log ~pace spot

let make ~log ~spot (plan : Capture_plan.t) : Capture.game_steps =
  let game_steps = B.Battle_steps.make () in
  {
    find_encounter = find_encounter ~log ~pace:plan.pace spot;
    read_encounter = read_encounter ~target:plan.target game_steps;
    flee = flee ~log game_steps;
    throw_ball = throw_ball ~log plan.ball;
    finish_catch = finish_catch ~log;
    log;
  }
