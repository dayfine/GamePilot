let degrees_per_half_turn = 180.0

let toward ~degrees =
  let radians = degrees *. Float.pi /. degrees_per_half_turn in
  Wire.stick (sin radians) (cos radians)

type run = { button : Wire.button; speedup : float }

let run_ms run duration_ms =
  int_of_float (float_of_int duration_ms /. run.speedup)

let press ?run ~duration_ms ~release_ms left_stick =
  match run with
  | Some run ->
      Wire.press ~left_stick ~hold_ms:(run_ms run duration_ms)
        ~cooldown_ms:release_ms [ run.button ]
  | None ->
      Wire.press ~left_stick ~hold_ms:duration_ms ~cooldown_ms:release_ms []

let tilt ?run ~degrees ~duration_ms ~release_ms () =
  Result.map (press ?run ~duration_ms ~release_ms) (toward ~degrees)
