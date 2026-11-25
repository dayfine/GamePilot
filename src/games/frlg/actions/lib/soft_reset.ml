open Frlg_readers
module M = Menu_input

let combo_hold_ms = 360
let combo_release_ms = 1440
let select_mash_ms = 5000
let title_mash_ms = 1000
let title_wait_ms = 5000
let menu_settle_ms = 500
let continue_release_ms = 320

(* The fork's ENTER_GAME_WAIT0 default is 3000 ms; console B's lab-B profile
   sets it far higher, and its CONTINUE went black after 3.6 s (2026-11-23).
   The wait ends as soon as black shows, so a long limit costs nothing. *)
let enter_game_wait_ms = 10_000
let recap_mash_ms = 3000
let attempts = 5

let probes =
  Load_menu.probes @ Screen_facts.probes @ Start_menu.probes
  @ Dialog.yes_no_probes

let wait ms = Wire.Wait { wait_ms = ms }

let combo =
  Wire.Press
    {
      buttons = [ Wire.A; B; Select; Start ];
      hold_ms = combo_hold_ms;
      cooldown_ms = combo_release_ms;
    }

let title_mash =
  let tap =
    M.hold ~hold_ms:M.tap_hold_ms ~cooldown_ms:M.tap_release_ms Wire.A
  in
  List.init (title_mash_ms / (M.tap_hold_ms + M.tap_release_ms)) (fun _ -> tap)
  @ [ wait title_wait_ms ]

let black m = (Screen_facts.of_measurements m).fade = Black

(* A screen no A may be pressed on: the reset was not taken (START opened
   the menu, which may sit on SAVE), or a box asks something. *)
let unsafe m =
  Start_menu.start_menu_open m
  || Option.is_some (Dialog.yes_no_cursor m)
  || Dialog.dialog_up m

let holds pred = Option.fold ~none:false ~some:pred (Effects.read ())

(* B (never A) until the menu or box is gone, then the attempt fails. *)
let back_out () =
  M.close "the menu or box" unsafe;
  M.fail "soft_reset_not_taken"
    "a menu or a box showed instead of the title: closed with B"

let to_load_menu () =
  if holds unsafe then back_out ()
  else if not (holds Load_menu.load_menu_open) then
    match
      Effects.race title_mash ~stop:(fun m ->
          Load_menu.load_menu_open m || unsafe m)
    with
    | Stopped m when unsafe m -> back_out ()
    | Stopped _ -> ()
    | Finished _ -> M.fail "soft_reset_no_menu" "the load menu did not show"

(* The fork's BlackScreenOverWatcher: black, then not. *)
let enter_game () =
  let over what pred =
    ignore
      (M.await_screen ~timeout_ms:enter_game_wait_ms ~code:"soft_reset_no_game"
         what pred)
  in
  over "the black screen after CONTINUE" black;
  over "the game after the black screen" (fun m -> not (black m))

let attempt ~log () =
  log "Soft reset: A + B + SELECT + START.";
  ignore (Effects.submit [ combo ]);
  M.mash Wire.Select select_mash_ms;
  to_load_menu ();
  log "Soft reset: the load menu; CONTINUE.";
  ignore (Effects.submit [ wait menu_settle_ms ]);
  if not (holds Load_menu.load_menu_open) then
    M.fail "soft_reset_no_menu" "the load menu went away before CONTINUE";
  M.press ~cooldown_ms:continue_release_ms Wire.A;
  enter_game ();
  M.mash Wire.B recap_mash_ms;
  M.settle_back ~label:"soft reset" ~log

let rec attempts_from n ~log =
  match Effects.with_probes probes (attempt ~log) with
  | () -> log "Soft reset completed."
  | exception M.Action_failed cause when n < attempts ->
      log
        (Printf.sprintf "Soft reset: attempt %d failed: %s" n
           (Checkpoints_run.Failure.cause_to_string cause));
      attempts_from (n + 1) ~log
  | exception M.Action_failed cause ->
      M.fail ~repeats:true "soft_reset_failed"
        (Printf.sprintf "%d attempts; the last: %s" attempts
           (Checkpoints_run.Failure.cause_to_string cause))

let return_to_save ~log () = M.run (fun () -> attempts_from 1 ~log)
