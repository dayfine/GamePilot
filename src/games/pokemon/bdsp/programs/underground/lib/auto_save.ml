module OW = Bdsp_actions.Bdsp_overworld
module P = Switch_home.Switch_presses

let every_cycles = 3
let press_hold_ms = 120
let prompt_wait_ms = 1500
let finish_wait_ms = 5500
let max_dismiss_presses = 6

let run_save ~log ~picture =
  log "Auto-saving progress in Grand Underground (X -> R -> A)...";
  match OW.open_menu ~log ~picture () with
  | Error e -> log ("Auto-save skipped (menu did not open): " ^ e)
  | Ok () ->
      P.press ~hold_ms:press_hold_ms ~cooldown_ms:prompt_wait_ms Wire.R;
      P.press ~hold_ms:press_hold_ms ~cooldown_ms:finish_wait_ms Wire.A;
      ignore
        (OW.dismiss_dialog ~log ~picture ~max_presses:max_dismiss_presses ()
          : (unit, string) result);
      log "Auto-save complete."

let maybe_save ~log ~picture ~cycle_idx ~prev_shards
    (counters : Bdsp_underground.Mining_counters.t) =
  let cur_shards = counters.shard_s + counters.shard_l in
  if
    cur_shards > prev_shards
    || (cycle_idx mod every_cycles = 0 && counters.digs > 0)
  then run_save ~log ~picture
