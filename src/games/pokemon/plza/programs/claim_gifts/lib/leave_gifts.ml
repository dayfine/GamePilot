module Gifts = Plza_screens.Gifts
module Walk = Screen_graph.Screen_walk

let most_hops = 12
let read_ms = 2500

let to_main_menu ~log =
  let steps = Screen_graph.Screen_walk_steps.make ~log Gifts.walk_graph in
  match
    Walk.go_to ~max_hops:most_hops ~within_ms:read_ms Gifts.walk_graph steps
      ~at:Gifts.is_main_menu
  with
  | Ok _ -> Ok ()
  | Error e -> Error (Walk.failure_to_string Gifts.walk_graph e)
