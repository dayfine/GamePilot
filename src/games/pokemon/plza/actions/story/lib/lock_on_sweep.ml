module S = Story_steps

let stick_ms = 1000
let dpad_ms = 160
let mash_ms = 40
let zl_hold_ms = 500
let recenter_hold_ms = 160
let recenter_release_ms = 160

(* The mash's taps over the stick's second, D-pad up held through the first
   160 ms. *)
let tap right_stick i =
  let up = i * mash_ms < dpad_ms in
  let buttons =
    (if i mod 2 = 0 then [ Wire.ZL ] else []) @ if up then [ Wire.Up ] else []
  in
  Wire.press ?right_stick ~hold_ms:mash_ms ~cooldown_ms:0 buttons

(* One round's inputs. *)
let round_inputs ~camera_x =
  let right_stick = Result.to_option (Wire.stick camera_x 0.) in
  List.init (stick_ms / mash_ms) (tap right_stick)
  @ [ Wire.press ~hold_ms:zl_hold_ms ~cooldown_ms:0 [ Wire.ZL ] ]

let rec sweep steps ~camera_x ~rounds =
  rounds > 0
  && (Option.is_some
        (S.(steps.race_batch) (round_inputs ~camera_x) Story_look.moves_shown)
     || sweep steps ~camera_x ~rounds:(rounds - 1))

let run steps ~camera_x ~rounds =
  let locked = sweep steps ~camera_x ~rounds in
  if not locked then
    S.press steps Wire.L ~hold_ms:recenter_hold_ms
      ~release_ms:recenter_release_ms;
  locked
