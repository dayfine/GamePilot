(* Port of rng_reset_and_return_home (PokemonFRLG_HardReset.cpp) and the
   opening A press of perform_blind_sequence (PokemonFRLG_BlindNavigation.cpp)
   for Switch RNG attempts, alongside mGBA's Effects.reset. *)

type mode =
  | Mgba
  | Switch of { picture : Wire.box; tile : Switch.Home_screen.tile_color }

let home_hold_ms = 200
let home_cooldown_ms = 1800
let resume_hold_ms = 80

let switch_resume_press =
  Wire.press ~hold_ms:resume_hold_ms ~cooldown_ms:0 [ A ]

let or_fail ~stage = function
  | Ok () -> ()
  | Error msg ->
      Menu_input.fail "rng_reset_failed"
        (Printf.sprintf "Switch RNG hard reset (%s): %s" stage msg)

let reset_switch_to_home ~log ~picture ~tile =
  log "RNG reset (Switch): closing FireRed from HOME.";
  or_fail ~stage:"close"
    (Switch.Console_park.park_and_close ~log ~picture ~tile ());
  log "RNG reset (Switch): cold-launching FireRed past license check.";
  or_fail ~stage:"launch"
    (Switch.Game_entry.start_game ~log ~picture ~game_slot:0 ~user_slot:0 tile);
  log "RNG reset (Switch): pausing cold boot on HOME.";
  ignore
    (Effects.submit
       [
         Wire.press ~hold_ms:home_hold_ms ~cooldown_ms:home_cooldown_ms [ Home ];
       ]
      : Wire.batch_done);
  or_fail ~stage:"return_home" (Switch.Console_park.park ~log ~picture tile)

let reset_and_submit ~log mode presses =
  match mode with
  | Mgba ->
      let seq = Effects.reset () in
      log
        (Printf.sprintf "RNG reset (mGBA): reset (seq %d), blind presses." seq);
      ignore (Effects.submit presses : Wire.batch_done)
  | Switch { picture; tile } ->
      reset_switch_to_home ~log ~picture ~tile;
      log "RNG reset (Switch): resuming from HOME for blind presses.";
      ignore (Effects.submit (switch_resume_press :: presses) : Wire.batch_done)
