open Plza_terms
open Walk_args
module T = Plza_terms

let pose ({ place; spot } : Pose.t) =
  match spot with Some s -> place ^ "/" ^ s | None -> place

let observed = pose
let leg { turn; walk_ms } = Printf.sprintf "[%g, %d]" turn walk_ms

let until = function
  | None -> []
  | Some Scene -> [ "until scene" ]
  | Some (Event e) -> [ "until " ^ end_event_name e ]

let walk { move; until = u; end_after_ms } =
  String.concat " "
    (("walk" :: List.map leg move.legs)
    @ (if move.style = Held then [ "held" ] else [])
    @ (if move.wait_first_ms > 0 then
         [ Printf.sprintf "after %d ms" move.wait_first_ms ]
       else [])
    @ until u
    @
    if end_after_ms > 0 then [ Printf.sprintf "not before %d ms" end_after_ms ]
    else [])

let kind : Kind.t -> string = function Walk w -> walk w
let postconditions () = []
