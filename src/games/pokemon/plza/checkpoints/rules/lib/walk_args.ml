type leg = { angle_deg : float; walk_ms : int }
type style = Face_then_walk | Steer
type move = { legs : leg list; style : style; wait_before_ms : int }
type end_event = Fade_white | Fade_black | Dialog | Prompt
type until = Scene | Event of end_event | Talk of { after_legs : bool }

type t = {
  move : move;
  until : until option;
  earliest_end_ms : int;
  heading_deg : float option;
}

(* In the order the C++ lists them. *)
let end_events =
  [
    ("fade_white", Fade_white);
    ("fade_black", Fade_black);
    ("dialog", Dialog);
    ("prompt", Prompt);
  ]

let end_event_name event = fst (List.find (fun (_, e) -> e = event) end_events)
let end_event_of_name name = List.assoc_opt name end_events
let styles = [ ("face_then_walk", Face_then_walk); ("steer", Steer) ]
let style_of_name name = List.assoc_opt name styles
let leg { angle_deg; walk_ms } = Printf.sprintf "[%g, %d]" angle_deg walk_ms

let until = function
  | None -> []
  | Some Scene -> [ "until scene" ]
  | Some (Event e) -> [ "until " ^ end_event_name e ]
  | Some (Talk { after_legs }) ->
      [ (if after_legs then "into a talk after the legs" else "into a talk") ]

let to_string { move; until = u; earliest_end_ms; heading_deg } =
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
