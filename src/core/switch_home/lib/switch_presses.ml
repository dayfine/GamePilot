let press ~hold_ms ~cooldown_ms b =
  ignore
    (Effects.submit [ Wire.press ~hold_ms ~cooldown_ms [ b ] ]
      : Wire.batch_done)

let mash_hold_ms = 40
let mash_cooldown_ms = 24

(* issue_mash_button presses until the duration is used up, a period at a
   time. *)
let mash_presses b ms =
  let period = mash_hold_ms + mash_cooldown_ms in
  List.init
    ((ms + period - 1) / period)
    (fun _ ->
      Wire.press ~hold_ms:mash_hold_ms ~cooldown_ms:mash_cooldown_ms [ b ])

let mash b ms = ignore (Effects.submit (mash_presses b ms) : Wire.batch_done)

let wait ms =
  ignore (Effects.submit [ Wire.Wait { wait_ms = ms } ] : Wire.batch_done)
