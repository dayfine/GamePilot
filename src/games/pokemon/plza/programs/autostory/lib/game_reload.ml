module G = Switch_home.Game_entry

let tile_color : Switch_home.Home_screen.tile_color =
  { min = (0, 120, 120); max = (120, 255, 255) }

let start_game_wait_ms = 40_000
let enter_game_wait_ms = 60_000
let mash_ms = 2000
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

let to_game ~log =
  log "[Reload] mashing A to enter game...";
  let commands =
    Switch_home.Switch_presses.mash_presses Wire.A mash_ms
    @ [ Wire.Wait { wait_ms = enter_game_wait_ms } ]
  in
  match Effects.race commands ~stop:Plza_readers.Game_loading.entering with
  | Finished _ -> Error "no black screen after A on the title"
  | Stopped _ ->
      log "[Reload] black screen detected";
      let* () =
        await ~what:"the black screen did not end"
          ~timeout_ms:enter_game_wait_ms (fun m ->
            not (Plza_readers.Game_loading.entering m))
      in
      log "[Reload] entered game";
      Ok (Switch_home.Switch_presses.wait settle_ms)

let reload ~log ~picture =
  let* () = G.close_game ~log ~picture tile_color in
  let* () = G.start_game ~log ~picture ~game_slot:1 ~user_slot:0 tile_color in
  let* () = to_game_menu ~log in
  to_game ~log
