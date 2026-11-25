module S = Story_steps

let tilt_ms = 100
let lift_ms = 500

(* The right stick held up or down for [tilt_ms]; [cooldown_ms] after. *)
let tilt y ~cooldown_ms =
  Result.map
    (fun right_stick ->
      Wire.press ~right_stick ~hold_ms:tilt_ms ~cooldown_ms [])
    (Wire.stick 0. y)

let run steps =
  match (tilt 1. ~cooldown_ms:0, tilt (-1.) ~cooldown_ms:lift_ms) with
  | Ok up, Ok down -> S.(steps.submit_batch) [ up; down ]
  | _ -> S.wait steps lift_ms
