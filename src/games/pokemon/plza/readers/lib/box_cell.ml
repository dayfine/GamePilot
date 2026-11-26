let left_id = "box_cell.left_white"
let right_id = "box_cell.right_white"

let left =
  Native_box.of_fractions
    { left = 0.453; top = 0.100; width = 0.009; height = 0.059 }

let right =
  Native_box.of_fractions
    { left = 0.947; top = 0.107; width = 0.010; height = 0.052 }

let white_min_sum = 500.
let white_max_stddev_sum = 15.

let probes ~picture =
  Box_color.probe ~picture ~id:left_id left
  @ Box_color.probe ~picture ~id:right_id right

let white m id =
  match Box_color.read m id with
  | Some s ->
      Box_color.is_white ~min_sum:white_min_sum
        ~max_stddev_sum:white_max_stddev_sum s
  | None -> false

let holds_pokemon m = white m left_id && white m right_id
