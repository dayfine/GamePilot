(** A walk to a point on the full map, planned from one pin read at a time.
    Ported from PokemonLZA_AutoStoryMapLegs.cpp/.h: its bearing between two map
    points and its leg. *)

type point = { x : float; y : float }
(** A point on the full map: the frame scaled to 800 x 450 (a map point of the
    fork's PokemonLZA_MapPoint.h). *)

type waypoint = { name : string; pin : point; stop_radius : float }
(** A walk's target (the fork's waypoints, PokemonLZA_AutoStoryZone1.h). *)

val bearing : point -> point -> float
(** [bearing from to]: the minimap bearing, degrees clockwise from north (0 up,
    90 right), 0 to under 360. *)

type move =
  | Arrived
  | Walk of { heading : float; hold_ms : int; correction : int }
      (** face [heading] and walk [hold_ms]; [correction] 0 for the first walk
      *)
  | Read_again  (** no pin: look at the map once more *)
  | Off_target  (** still off after the walk and two corrections *)
  | Pin_not_read  (** no pin twice in a row *)

type t
(** One leg: its target and the walks so far. *)

val start : point -> stop_radius:float -> t
(** A leg to the point. Within 6 of it (about 5 marker units) is there; within
    [stop_radius] is there too, unless the pin is short of the target along the
    last walk's way. *)

val next : t -> point option -> t * move
(** The move after a pin read ([None]: not read). A walk's hold is the distance
    at 7 map pixels a second (the median of 35 measured legs was 6.9, the long
    ones 7.0; at 6.7 every long leg overshot). *)

val move_text : move -> string
(** "arrived", "walk 254 deg", "correction 1: walk 253 deg", "read again", "off
    target", "pin not read": as the fork's tests describe them. *)
