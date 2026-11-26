open Frlg_readers
module M = Menu_input
module D = Save_dialog

let yes_no_timeout_ms = 5000
let save_timeout_ms = 30000
let poll_ms = 300
let ms_per_s = 1000
let save_press_ms = 1500
let yes_press_ms = 1000
let page_press_ms = 500
let tap_hold_ms = 160
let tap_release_ms = 400
let start_press_ms = 1200
let close_press_ms = 600

let classify m : D.screen =
  if Option.is_some (Dialog.yes_no_cursor m) then Yes_no
  else if Start_menu.start_menu_open m then Start_menu
  else if Dialog.advance_arrow m then Paged_text
  else if Dialog.dialog_up m then Text
  else Nothing

let latest () = Effects.read ()
let pause ms = ignore (Effects.submit [ Wire.Wait { wait_ms = ms } ])

let answer_yes ~log m =
  if Dialog.yes_no_cursor m = Some false then
    ignore
      (Effects.submit
         [ M.hold ~hold_ms:tap_hold_ms ~cooldown_ms:tap_release_ms Wire.Up ]);
  log "Save: YES.";
  M.press ~cooldown_ms:yes_press_ms Wire.A

(* The fork's overworld_shows(): START opens the menu, B closes it. *)
let overworld_shows () =
  M.press ~cooldown_ms:start_press_ms Wire.Start;
  match latest () with
  | Some m when Start_menu.start_menu_open m ->
      M.press ~cooldown_ms:close_press_ms Wire.B;
      true
  | _ -> false

let act ~log m : D.action -> bool = function
  | Wait ->
      pause poll_ms;
      false
  | Answer_yes ->
      answer_yes ~log m;
      false
  | Next_page ->
      M.press ~cooldown_ms:page_press_ms Wire.A;
      false
  | Check_overworld -> overworld_shows ()
  | Fail_cancelled ->
      M.fail "save_cancelled" "the START menu came back: the save was cancelled"
  | Fail_error ->
      M.fail "save_error" "a message after the last YES: the save failed"

let rec dialog ~log ~deadline state =
  if Effects.now () > deadline then
    M.fail "save_timeout"
      (Printf.sprintf "not back on the overworld %d s after saving"
         (save_timeout_ms / ms_per_s))
  else
    match latest () with
    | None ->
        pause poll_ms;
        dialog ~log ~deadline state
    | Some m ->
        let state, action = D.next state (classify m) in
        if act ~log m action then log "Saved." else dialog ~log ~deadline state

(* SAVE found by its name; B out of the menu when it is not there. *)
let choose_save ~log =
  Menu_cursor.open_start_menu ();
  let rows = Start_menu_names.read_rows () in
  match Start_menu_names.row_of "SAVE" rows with
  | Some row ->
      log (Printf.sprintf "Save: SAVE on row %d." row);
      Menu_cursor.choose ~code:"no_start_menu" Menu_cursor.start_menu row
        ~taken:Menu_cursor.start_menu_taken
  | None ->
      M.close "the Start menu" Start_menu.start_menu_open;
      M.fail ~repeats:true "save_not_on_menu" "no SAVE row on the Start menu"

let save ~log () =
  log "Saving the game.";
  choose_save ~log;
  pause save_press_ms;
  ignore
    (M.await_screen ~timeout_ms:yes_no_timeout_ms ~code:"save_no_question"
       "the save's YES/NO" (fun m -> classify m = Yes_no));
  dialog ~log ~deadline:(Effects.now () +. float_of_int save_timeout_ms) D.start

let save_game ~log () =
  M.run (fun () -> Effects.with_probes Dialog.yes_no_probes (save ~log))
