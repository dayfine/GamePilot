let every_cycles = 3

let maybe_save ~log ~picture ~cycle_idx ~prev_shards
    (counters : Bdsp_underground.Mining_counters.t) =
  let cur_shards = counters.shard_s + counters.shard_l in
  if
    cur_shards > prev_shards
    || (cycle_idx mod every_cycles = 0 && counters.digs > 0)
  then
    match Bdsp_actions.Game_save.save_game ~log ~picture () with
    | Ok () -> ()
    | Error e -> log ("Auto-save skipped: " ^ e)
