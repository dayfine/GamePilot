module B = Switch_home.Black_screen
module H = Switch_home.Held_screen
module P = Switch_home.Switch_presses

let ( let* ) = Result.bind
let load_game_timeout_ms = 60_000
let enter_game_mash_ms = 5000
let enter_game_timeout_ms = 60_000
let default_post_wait_ms = 1000
let black_hold_ms = 100.
let clear_hold_ms = 250.
let is_black m = if B.shown m then Some () else None
let is_not_black m = if not (B.shown m) then Some () else None

let wait_black_over ~timeout_ms =
  match H.wait_for ~timeout_ms (H.held black_hold_ms is_black) with
  | None -> Error "timed out waiting for load fade (black screen)"
  | Some () -> (
      match H.wait_for ~timeout_ms (H.held clear_hold_ms is_not_black) with
      | None -> Error "timed out waiting for overworld after black screen"
      | Some () -> Ok ())

let openedgame_to_ingame ~log ~picture ?(post_wait_ms = default_post_wait_ms) ()
    =
  ignore (Effects.subscribe (B.probes ~picture) : string list);
  log "Waiting for BDSP title screen...";
  let* () =
    match
      H.wait_for ~timeout_ms:load_game_timeout_ms
        (H.held clear_hold_ms is_not_black)
    with
    | Some () -> Ok ()
    | None -> Error "timed out waiting for BDSP title screen"
  in
  log "Mashing A to enter game...";
  P.mash Wire.A enter_game_mash_ms;
  log "Waiting for load fade into overworld...";
  let* () = wait_black_over ~timeout_ms:enter_game_timeout_ms in
  log "Entered game! Waiting out grace period.";
  if post_wait_ms > 0 then P.wait post_wait_ms;
  Ok ()
