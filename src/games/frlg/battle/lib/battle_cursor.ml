let fight = Wire.[ Left; Up; A ]
let bag = Wire.[ Left; Up; Right; A ]
let pokemon = Wire.[ Right; Up; Left; Down; A ]
let run_away = Wire.[ Left; Up; Right; Down; A ]

let move ~slot =
  (Wire.[ Left; Up ] @ if slot land 1 = 1 then [ Wire.Right ] else [])
  @ if slot >= 2 then [ Wire.Down ] else []

let target : Battle_driver.target -> Wire.button list = function
  | Default | Foe_left -> []
  | Ally -> [ Wire.Right ]
  | Foe_right -> [ Wire.Left ]

let down n = List.init n (fun _ -> Wire.Down)
