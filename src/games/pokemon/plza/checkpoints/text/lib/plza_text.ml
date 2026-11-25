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
  | Some (Talk { after_legs }) ->
      [ (if after_legs then "into a talk after the legs" else "into a talk") ]

let walk { move; until = u; earliest_end_ms; heading_deg } =
  String.concat " "
    (("walk" :: List.map leg move.legs)
    @ (if move.style = Steer then [ "steer" ] else [])
    @ (if move.wait_before_ms > 0 then
         [ Printf.sprintf "after %d ms" move.wait_before_ms ]
       else [])
    @ (match heading_deg with
      | Some h -> [ Printf.sprintf "facing %.0f" h ]
      | None -> [])
    @ until u
    @
    if earliest_end_ms > 0 then
      [ Printf.sprintf "not before %d ms" earliest_end_ms ]
    else [])

let action : Action.t -> string = function Walk w -> walk w
let postconditions () = []
