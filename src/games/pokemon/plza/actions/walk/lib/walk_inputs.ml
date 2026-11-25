type pace = Walk | Run

let run_speedup = 1.65
let run = { Switch_home.Stick_tilt.button = Wire.B; speedup = run_speedup }

let tilt ~walk_only pace ~degrees ~duration_ms ~release_ms =
  let run = match pace with Run when not walk_only -> Some run | _ -> None in
  Switch_home.Stick_tilt.tilt ?run ~degrees ~duration_ms ~release_ms ()

let button b ~hold_ms ~release_ms =
  Wire.press ~hold_ms ~cooldown_ms:release_ms [ b ]

let wait wait_ms = Wire.Wait { wait_ms }
