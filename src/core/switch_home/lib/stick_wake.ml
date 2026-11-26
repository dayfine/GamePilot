let tilt_ms = 100
let lift_ms = 500

(* The right stick held up or down for [tilt_ms]; [cooldown_ms] after. *)
let tilt y ~cooldown_ms =
  Result.map
    (fun right_stick ->
      Wire.press ~right_stick ~hold_ms:tilt_ms ~cooldown_ms [])
    (Wire.stick 0. y)

let commands =
  match (tilt 1. ~cooldown_ms:0, tilt (-1.) ~cooldown_ms:lift_ms) with
  | Ok up, Ok down -> [ up; down ]
  | _ -> [ Wire.Wait { wait_ms = lift_ms } ]

let run () = ignore (Effects.submit commands : Wire.batch_done)
