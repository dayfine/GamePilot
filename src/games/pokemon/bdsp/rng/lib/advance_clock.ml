type t = {
  anchor_time : float;
  anchor_advance : int;
  tick_seconds : float;
  npcs : int;
}

let micro = 1e6
let micros time = Float.round (time *. micro)

let plus_seconds time seconds =
  (micros time +. Float.trunc (seconds *. micro)) /. micro

let seconds_between ~earlier later = (micros later -. micros earlier) /. micro

let advance_at clock time =
  let elapsed = seconds_between ~earlier:clock.anchor_time time in
  let advances = elapsed /. clock.tick_seconds *. float_of_int clock.npcs in
  let position = float_of_int clock.anchor_advance +. advances in
  if position <= 0.0 then 0 else int_of_float position

let time_of_advance clock advance =
  if clock.npcs = 0 then clock.anchor_time
  else
    let ticks = (advance / clock.npcs) - (clock.anchor_advance / clock.npcs) in
    plus_seconds clock.anchor_time (float_of_int ticks *. clock.tick_seconds)

let middle_of_advance clock advance =
  plus_seconds (time_of_advance clock advance) (-.clock.tick_seconds /. 2.0)
