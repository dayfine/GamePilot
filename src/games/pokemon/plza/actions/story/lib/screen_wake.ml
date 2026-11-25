module S = Story_steps

let tilt_x = 1.0
let tilt_ms = 100
let lift_ms = 500

let run steps =
  match Wire.stick tilt_x 0. with
  | Ok right_stick ->
      S.(steps.submit)
        (Wire.press ~right_stick ~hold_ms:tilt_ms ~cooldown_ms:lift_ms [])
  | Error _ -> S.wait steps lift_ms
