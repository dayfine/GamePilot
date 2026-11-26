let tens = 10

let presses_from_one quantity =
  if quantity <= 1 then (0, 0)
  else
    let right = (quantity - 1) / tens in
    (right, quantity - 1 - (right * tens))

let next_press ~now ~target ~most =
  if now = target then None
  else if now = 1 && target = most then Some Wire.Down
  else if target - now >= tens then Some Wire.Right
  else if now - target >= tens then Some Wire.Left
  else if target > now then Some Wire.Up
  else Some Wire.Down
