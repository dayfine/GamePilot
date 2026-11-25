type pace = Walk | Run

let run_speedup = 1.65
let degrees_per_half_turn = 180.0

let stick_toward ~degrees =
  let radians = degrees *. Float.pi /. degrees_per_half_turn in
  Wire.stick (sin radians) (cos radians)

let run_ms duration_ms = int_of_float (float_of_int duration_ms /. run_speedup)

let tilted ~walk_only pace ~duration_ms ~release_ms left_stick =
  match pace with
  | Run when not walk_only ->
      Wire.press ~left_stick ~hold_ms:(run_ms duration_ms)
        ~cooldown_ms:release_ms [ Wire.B ]
  | Walk | Run ->
      Wire.press ~left_stick ~hold_ms:duration_ms ~cooldown_ms:release_ms []

let tilt ~walk_only pace ~degrees ~duration_ms ~release_ms =
  Result.map
    (tilted ~walk_only pace ~duration_ms ~release_ms)
    (stick_toward ~degrees)

let button b ~hold_ms ~release_ms =
  Wire.press ~hold_ms ~cooldown_ms:release_ms [ b ]

let wait wait_ms = Wire.Wait { wait_ms }
