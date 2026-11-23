(** A leg of a route as the route log names it: ["east 15 (to wall)"],
    ["surf east"], ["open gate west"]. *)

(** What the leg does. *)
type action =
  | Walk
  | Surf
  | Face
  | Open_gate  (** Face a gate and press A: a card-key gate opens. *)
  | Press_switch  (** Face a statue and press A, then Yes: a switch flips. *)

(** How a walk ends: where it is timed to, at a wall, or on a warp. *)
type leg_end = Open | Wall | Warp

type t = {
  action : action;
  direction : Grid_maps.Direction.t;
  tiles : int;
  leg_end : leg_end;
}

val to_string : t -> string
(** ["east 15 (to wall)"], ["south 4 (open)"], ["north 1 (warp)"],
    ["surf east"], ["face west"], ["open gate west"], ["press switch north"].
    Only a walk names its tiles and end. *)

type planned = { leg : t; after : Route_tile.t list }
(** A planned leg and the tiles it may end on. *)
