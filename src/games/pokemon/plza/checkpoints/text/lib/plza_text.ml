open Plza_rules
open Walk_args
module T = Plza_rules

let pose ({ place; spot } : Pose.t) =
  match spot with Some s -> place ^ "/" ^ s | None -> place

let observed = pose
let leg { angle_deg; walk_ms } = Printf.sprintf "[%g, %d]" angle_deg walk_ms

let until = function
  | None -> []
  | Some Scene -> [ "until scene" ]
  | Some (Event e) -> [ "until " ^ end_event_name e ]

let walk { move; until = u; earliest_end_ms } =
  String.concat " "
    (("walk" :: List.map leg move.legs)
    @ (if move.style = Steer then [ "steer" ] else [])
    @ (if move.wait_before_ms > 0 then
         [ Printf.sprintf "after %d ms" move.wait_before_ms ]
       else [])
    @ until u
    @
    if earliest_end_ms > 0 then
      [ Printf.sprintf "not before %d ms" earliest_end_ms ]
    else [])

let kind : Action.t -> string = function Walk w -> walk w
let postconditions () = []
