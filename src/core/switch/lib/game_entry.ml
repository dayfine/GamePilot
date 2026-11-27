module H = Home_screen
module P = Switch_presses

let ( let* ) = Result.bind
let held = Screen_graph.Held_screen.held
let wait_for = Screen_graph.Held_screen.wait_for

(* ConsoleSettings' defaults (NintendoSwitch_Settings.cpp) and how long each
   screen must hold before NintendoSwitch_GameEntry.cpp counts it. *)
type timings = {
  close_game_delay_ms : int;
  settings_to_home_delay_ms : int;
  button_hold_ms : int;
  watcher_hold_ms : float;
  black_hold_ms : float;
  home_again_hold_ms : float;
  home_wait_ms : int;
  home_retries : int;
  close_rounds : int;
  close_wait_ms : int;
  user_select_mash_ms : int;
  close_mash_ms : int;
  scroll_delay_ms : int;
  home_cooldown_ms : int;
  dpad_ms : int;
  user_lefts : int;
  b_until_home_ms : int;
  after_home_ms : int;
  first_a_cooldown_ms : int;
  a_cooldown_ms : int;
  state_wait_ms : int;
  settle_ms : int;
  start_rounds : int;
}

let t =
  {
    close_game_delay_ms = 2000;
    settings_to_home_delay_ms = 960;
    button_hold_ms = 160;
    watcher_hold_ms = 250.;
    black_hold_ms = 100.;
    home_again_hold_ms = 2000.;
    home_wait_ms = 5000;
    home_retries = 10;
    close_rounds = 20;
    close_wait_ms = 10_000;
    user_select_mash_ms = 500;
    close_mash_ms = 800;
    scroll_delay_ms = 24;
    home_cooldown_ms = 500;
    dpad_ms = 160;
    user_lefts = 9;
    b_until_home_ms = 10_000;
    after_home_ms = 100;
    first_a_cooldown_ms = 840;
    a_cooldown_ms = 40;
    state_wait_ms = 30_000;
    settle_ms = 100;
    start_rounds = 10;
  }

type screen = Close_game | Home | User_select

(* A dimmed HOME counts as HOME (deliberately: the fork has no dimmed HOME,
   and a HOME press there would resume the game). *)
let screen_of m =
  if Close_game_popup.shown m then Some Close_game
  else
    match H.read m with
    | H.Home _ | Home_dimmed -> Some Home
    | User_select -> Some User_select
    | Elsewhere -> None

(* Watches for one screen: [Some ()] while it shows. *)
let screen_is s m = if screen_of m = Some s then Some () else None

(* ensure_at_home: up to 10 tries of 5 s for HOME, HOME pressed after each. *)
let rec ensure_at_home ~log attempts =
  if attempts >= t.home_retries then Error "Unable to find Switch Home"
  else
    match
      wait_for ~timeout_ms:t.home_wait_ms
        (held t.watcher_hold_ms (screen_is Home))
    with
    | Some () ->
        log "Home detected.";
        Ok ()
    | None ->
        log "Unable to detect Home. Pressing Home button...";
        P.press ~hold_ms:t.button_hold_ms ~cooldown_ms:t.button_hold_ms
          Wire.Home;
        ensure_at_home ~log (attempts + 1)

let go_home ~log =
  log "Going Home...";
  P.press ~hold_ms:t.button_hold_ms ~cooldown_ms:0 Wire.Home;
  ensure_at_home ~log 0

(* ssf_issue_scroll(DOWN, 24ms): held 48, then 24. *)
let scroll_down () =
  P.press ~hold_ms:(2 * t.scroll_delay_ms) ~cooldown_ms:t.scroll_delay_ms
    Wire.Down

let reselect_and_close ~log =
  log
    "Failed to close game once. Either game is already closed, or the game is \
     not selected.";
  List.iter scroll_down [ (); (); () ];
  log "Click the Home button to ensure that current game is selected.";
  P.press ~hold_ms:t.button_hold_ms ~cooldown_ms:t.home_cooldown_ms Wire.Home;
  let* () = go_home ~log in
  log "Try again to close the game.";
  P.mash Wire.X t.close_mash_ms;
  Ok ()

type close_state = { seen : bool; homes : int }
type 'a step = Again of 'a | Done of (unit, string) result

(* One round of close_game_from_home's loop, on the screen that held. *)
let close_step ~log st = function
  | Some Close_game ->
      log "Detected close game menu.";
      P.press ~hold_ms:t.button_hold_ms ~cooldown_ms:t.close_game_delay_ms
        Wire.A;
      Again { st with seen = true }
  | Some Home when st.seen -> Done (Ok ())
  | Some Home when st.homes = 0 ->
      P.mash Wire.X t.close_mash_ms;
      Again { st with homes = 1 }
  | Some Home when st.homes = 1 -> (
      match reselect_and_close ~log with
      | Ok () -> Again { st with homes = 2 }
      | Error e -> Done (Error e))
  | Some Home ->
      log "Game was already closed.";
      Done (Ok ())
  | Some User_select ->
      log "Detected user select. (unexpected)";
      P.mash Wire.B t.user_select_mash_ms;
      Again { st with seen = true }
  | None ->
      P.press ~hold_ms:t.button_hold_ms ~cooldown_ms:t.home_cooldown_ms
        Wire.Home;
      log
        "Failed to detect either the Home screen or the Close game menu after \
         10 seconds.";
      Again st

let rec close_loop ~log st round =
  if round >= t.close_rounds then
    Error (Printf.sprintf "the game did not close in %d rounds" t.close_rounds)
  else
    let screen =
      wait_for ~timeout_ms:t.close_wait_ms (held t.watcher_hold_ms screen_of)
    in
    match close_step ~log st screen with
    | Done r -> r
    | Again st -> close_loop ~log st (round + 1)

let close_game ~log ~picture color =
  Effects.with_probes
    (H.probes ~picture color @ Close_game_popup.probes ~picture)
    (fun () ->
      log "Closing game from HOME.";
      let* () = ensure_at_home ~log 0 in
      close_loop ~log { seen = false; homes = 0 } 0)

(* move_to_user: Left 9 times (one spare in case one is dropped), then Right
   to the slot (from 1; 0 stays). *)
let dpad b = P.press ~hold_ms:t.dpad_ms ~cooldown_ms:t.dpad_ms b

let move_to_user user_slot =
  if user_slot <> 0 then (
    for _ = 1 to t.user_lefts do
      dpad Wire.Left
    done;
    for _ = 2 to user_slot do
      dpad Wire.Right
    done)

let b_until_home () =
  let home = held t.watcher_hold_ms (screen_is Home) in
  match
    Effects.race (P.mash_presses Wire.B t.b_until_home_ms) ~stop:(fun m ->
        Option.is_some (home m))
  with
  | Stopped _ -> Ok ()
  | Finished _ -> Error "Failed to detect Home screen after 10 seconds."

let to_game_slot game_slot =
  if game_slot <> 0 then (
    P.press ~hold_ms:t.button_hold_ms
      ~cooldown_ms:(t.settings_to_home_delay_ms - t.button_hold_ms)
      Wire.Home;
    for _ = 2 to game_slot do
      dpad Wire.Right
    done)

type after_a = Black | Home_again | User_select_shown

(* The round's watchers, the black one kept across rounds (run_until). *)
let after_a_watch ~black =
  let home = held t.home_again_hold_ms (screen_is Home)
  and user = held t.watcher_hold_ms (screen_is User_select) in
  fun m ->
    let b = black m and h = home m and u = user m in
    match (b, h, u) with
    | Some (), _, _ -> Some Black
    | None, Some (), _ -> Some Home_again
    | None, None, Some () -> Some User_select_shown
    | None, None, None -> None

let press_a () =
  P.press ~hold_ms:t.button_hold_ms ~cooldown_ms:t.a_cooldown_ms Wire.A

(* One round of the start's loop, on the screen that held. *)
let start_step ~log ~user_slot = function
  | Some Black -> Done (Ok ())
  | Some Home_again ->
      P.wait t.settle_ms;
      log "Detected home screen (again).";
      press_a ();
      Again ()
  | Some User_select_shown ->
      P.wait t.settle_ms;
      log "Detected user-select screen.";
      move_to_user user_slot;
      press_a ();
      Again ()
  | None -> (
      log "No recognizable state after 30 seconds.";
      match go_home ~log with Ok () -> Again () | Error e -> Done (Error e))

let rec start_loop ~log ~user_slot ~black round =
  if round >= t.start_rounds then Error "Failed to start game."
  else
    let screen = wait_for ~timeout_ms:t.state_wait_ms (after_a_watch ~black) in
    match start_step ~log ~user_slot screen with
    | Done r -> r
    | Again () -> start_loop ~log ~user_slot ~black (round + 1)

let black_watch () =
  held t.black_hold_ms (fun m -> if Black_screen.shown m then Some () else None)

(* The first A, watching for the black while it runs. *)
let first_a_shows_black black =
  let a =
    Wire.press ~hold_ms:t.button_hold_ms ~cooldown_ms:t.first_a_cooldown_ms
      [ A ]
  in
  match Effects.race [ a ] ~stop:(fun m -> Option.is_some (black m)) with
  | Stopped _ -> true
  | Finished _ -> false

let start_game ~log ~picture ~game_slot ~user_slot color =
  Effects.with_probes
    (H.probes ~picture color @ Black_screen.probes ~picture)
    (fun () ->
      let* () = b_until_home () in
      log "Detected Home screen.";
      P.wait t.after_home_ms;
      to_game_slot game_slot;
      let black = black_watch () in
      let started =
        if first_a_shows_black black then Ok ()
        else start_loop ~log ~user_slot ~black 0
      in
      Result.map
        (fun () -> log "Detected black screen. Game started...")
        started)
