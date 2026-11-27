module G = Switch.Game_entry

let tile_color = Plza_readers.Switch_home_tile.tile_color
let start_game_wait_ms = 40_000
let enter_game_wait_ms = 60_000
let mash_ms = 2000
let press_hold_ms = 160
let press_release_ms = 240
let settle_ms = 1000
let ( let* ) = Result.bind

let await ~what ~timeout_ms check =
  match Effects.await ~timeout_ms check with
  | Holds _ -> Ok ()
  | Timeout -> Error (Printf.sprintf "%s within %d ms" what timeout_ms)

let to_game_menu ~log =
  log "[Reload] waiting to load game...";
  let* () =
    await ~what:"no loading screen" ~timeout_ms:start_game_wait_ms
      Plza_readers.Game_loading.loading
  in
  log "[Reload] waiting for game menu...";
  await ~what:"the loading screen did not end" ~timeout_ms:start_game_wait_ms
    (fun m -> not (Plza_readers.Game_loading.loading m))

let not_entering m = not (Plza_readers.Game_loading.entering m)

let through_black ~log =
  log "[Reload] black screen detected";
  let* () =
    await ~what:"the black screen did not end" ~timeout_ms:enter_game_wait_ms
      not_entering
  in
  log "[Reload] entered game";
  Ok (Switch.Switch_presses.wait settle_ms)

(* What stopped the mash: in the fork's watcher order. *)
type title = Entering | Dialog | Backup_save_arrow | Other

let title m =
  if Plza_readers.Game_loading.entering m then Entering
  else if Plza_readers.Dialog_box.blue_shown m then Dialog
  else if Plza_readers.Choice_arrow.backup_save_shown m then Backup_save_arrow
  else Other

let stops m = title m <> Other
let title_rounds = 10

let tap button =
  Switch.Switch_presses.press ~hold_ms:press_hold_ms
    ~cooldown_ms:press_release_ms button

let mash_until_black () =
  Effects.race
    (Switch.Switch_presses.mash_presses Wire.A mash_ms
    @ [ Wire.Wait { wait_ms = enter_game_wait_ms } ])
    ~stop:stops

let rec to_game ~log round =
  if round >= title_rounds then
    Error (Printf.sprintf "still on the title after %d rounds of A" round)
  else (
    log "[Reload] mashing A to enter game...";
    match mash_until_black () with
    | Finished _ -> Error "timed out waiting for the black screen after A"
    | Stopped m -> on_title ~log round (title m))

and on_title ~log round = function
  | Entering | Other -> through_black ~log
  | Dialog ->
      log "[Reload] detected dialog: B";
      tap Wire.B;
      to_game ~log (round + 1)
  | Backup_save_arrow ->
      log "[Reload] detected the backup save arrow: A";
      tap Wire.A;
      to_game ~log (round + 1)

let reload ~log ~picture =
  let* () = G.close_game ~log ~picture tile_color in
  let* () = G.start_game ~log ~picture ~game_slot:1 ~user_slot:0 tile_color in
  let* () = to_game_menu ~log in
  to_game ~log 0
