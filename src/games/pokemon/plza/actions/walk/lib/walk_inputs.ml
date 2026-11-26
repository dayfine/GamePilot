type pace = Walk | Run

(* 1.65: running covers this many times walking's distance in the same time
    (console B, 2026-11-19: 16.6 px/s walking, 27.0 px/s running on the full
    map), so a run is held for its walk time over this. *)
let run_speedup = 1.65
let run = { Switch.Stick_tilt.button = Wire.B; speedup = run_speedup }

let tilt ~walk_only pace ~degrees ~duration_ms ~release_ms =
  let run = match pace with Run when not walk_only -> Some run | _ -> None in
  Switch.Stick_tilt.tilt ?run ~degrees ~duration_ms ~release_ms ()

let button b ~hold_ms ~release_ms =
  Wire.press ~hold_ms ~cooldown_ms:release_ms [ b ]

let wait wait_ms = Wire.Wait { wait_ms }
