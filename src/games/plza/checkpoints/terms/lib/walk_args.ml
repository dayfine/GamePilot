type leg = { turn : float; walk_ms : int }
type style = Turn_then_walk | Held
type move = { legs : leg list; style : style; wait_first_ms : int }
type end_event = Fade_white | Fade_black | Dialog
type until = Scene | Event of end_event
type t = { move : move; until : until option; end_after_ms : int }

(* The order of the C++'s WALK_ENDS. *)
let end_events =
  [ ("fade_white", Fade_white); ("fade_black", Fade_black); ("dialog", Dialog) ]

let end_event_name event = fst (List.find (fun (_, e) -> e = event) end_events)
let end_event_of_name name = List.assoc_opt name end_events
