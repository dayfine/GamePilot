type point = { x : float; y : float }
type waypoint = { name : string; pin : point; stop_radius : float }

let half_turn = 180.
let full_turn = 360.

let bearing from to_ =
  let d =
    Float.atan2 (to_.x -. from.x) (from.y -. to_.y) *. half_turn /. Float.pi
  in
  if d < 0. then d +. full_turn else d

type move =
  | Arrived
  | Walk of { heading : float; hold_ms : int; correction : int }
  | Read_again
  | Off_target
  | Pin_not_read

type t = {
  target : point;
  stop_radius : float;
  walks : int;
  missed : bool;
  walked_from : point option;
}

let walk_pixels_per_second = 7.0
let tolerance = 6.
let corrections = 2
let ms_per_second = 1000.

let start target ~stop_radius =
  { target; stop_radius; walks = 0; missed = false; walked_from = None }

(* The miss projects forward onto the walk's way. *)
let in_stop_area leg pin distance =
  distance <= leg.stop_radius
  &&
  match leg.walked_from with
  | None -> true
  | Some from ->
      let way_x = leg.target.x -. from.x and way_y = leg.target.y -. from.y in
      ((pin.x -. leg.target.x) *. way_x) +. ((pin.y -. leg.target.y) *. way_y)
      >= 0.

let hold_ms distance =
  int_of_float (distance /. walk_pixels_per_second *. ms_per_second)

let walk leg pin distance =
  let heading = bearing pin leg.target in
  let move =
    Walk { heading; hold_ms = hold_ms distance; correction = leg.walks }
  in
  ({ leg with walks = leg.walks + 1; walked_from = Some pin }, move)

let read leg pin =
  let leg = { leg with missed = false } in
  let distance = Float.hypot (leg.target.x -. pin.x) (leg.target.y -. pin.y) in
  if distance <= tolerance || in_stop_area leg pin distance then (leg, Arrived)
  else if leg.walks > corrections then (leg, Off_target)
  else walk leg pin distance

let next leg = function
  | Some pin -> read leg pin
  | None when leg.missed -> (leg, Pin_not_read)
  | None -> ({ leg with missed = true }, Read_again)

let move_text = function
  | Arrived -> "arrived"
  | Walk { heading; correction = 0; _ } ->
      Printf.sprintf "walk %.0f deg" heading
  | Walk { heading; correction; _ } ->
      Printf.sprintf "correction %d: walk %.0f deg" correction heading
  | Read_again -> "read again"
  | Off_target -> "off target"
  | Pin_not_read -> "pin not read"
