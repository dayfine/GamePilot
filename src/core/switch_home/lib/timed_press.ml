type t = { button : Wire.button; hold_ms : int; cooldown_ms : int }

let command { button; hold_ms; cooldown_ms } =
  Wire.press ~hold_ms ~cooldown_ms [ button ]

let press_all = function
  | [] -> ()
  | presses ->
      ignore (Effects.submit (List.map command presses) : Wire.batch_done)

let press p = press_all [ p ]
let times n p = List.init (max 0 n) (fun _ -> p)
