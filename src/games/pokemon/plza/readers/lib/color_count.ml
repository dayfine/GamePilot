type range = { low : int * int * int; high : int * int * int }

let channel_max = 255

let white v =
  { low = (v, v, v); high = (channel_max, channel_max, channel_max) }

let dark v = { low = (0, 0, 0); high = (v, v, v) }

let probe ~picture ~id box { low; high } =
  Option.to_list
    (Option.map
       (fun box ->
         Wire.color_count_probe ~id ~box ~delivery:Every ~min:low ~max:high)
       (Native_box.probe_box ~picture box))

let share = Switch_home.Color_share.read
