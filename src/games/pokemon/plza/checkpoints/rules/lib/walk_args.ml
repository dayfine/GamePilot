type leg = { angle_deg : float; walk_ms : int }
type style = Face_then_walk | Steer
type move = { legs : leg list; style : style; wait_before_ms : int }
type end_event = Fade_white | Fade_black | Dialog
type until = Scene | Event of end_event | Talk of { after_legs : bool }
type t = { move : move; until : until option; earliest_end_ms : int }

(* In the order the C++ lists them. *)
let end_events =
  [ ("fade_white", Fade_white); ("fade_black", Fade_black); ("dialog", Dialog) ]

let end_event_name event = fst (List.find (fun (_, e) -> e = event) end_events)
let end_event_of_name name = List.assoc_opt name end_events
let styles = [ ("face_then_walk", Face_then_walk); ("steer", Steer) ]
let style_name style = fst (List.find (fun (_, s) -> s = style) styles)
let style_of_name name = List.assoc_opt name styles
