(** The weights of a robust plan ({!Robust_planner}) and the limits of its
    search. *)

type t = {
  per_tile : int;
  per_wild_tile : int;  (** Extra for each wild tile entered. *)
  per_wander_tile : int;
      (** Extra for each tile entered where someone wanders. *)
  per_leg : int;
  leg_not_at_wall : int;  (** Extra for a leg that stops in the open. *)
  open_error : int;
      (** An open leg of n tiles may end [open_error + n / open_error_per] tiles
          short or long. *)
  open_error_per : int;
      (** 0 adds no growth: every open leg is off by [open_error] at most, and
          by nothing if [open_error] is 0 too. *)
  exact_open_tiles : int;
      (** Open legs this many tiles or shorter land exactly. 0 keeps every open
          leg uncertain. *)
  per_open_tile : int;
      (** Extra per tile of an open leg: its timing error grows with its length.
      *)
  hold_open_legs : bool;
      (** Open legs that may end off (longer than [exact_open_tiles]) are held
          for their time ({!Robust_leg.t.held}), not tapped, and pay no
          [per_open_tile]: no such leg is planned whose possible ends past its
          shortest enter a wild or wander place or hop a ledge, so a long or
          short hold meets nothing a tap would not have. *)
  per_open_wild_tile : int;
      (** Extra per wild place an open leg enters, on top of [per_wild_tile]: a
          wild battle loses an open leg's count, while a leg to a wall just
          walks to the wall again. *)
  forbid_along_wander : bool;
      (** Reject legs that run along where someone wanders (two such places in a
          row, the leg's start among them). When false, wander tiles only pay
          [per_wander_tile]. *)
  max_open_tiles : int;  (** Longest open leg to consider. *)
  max_spread : int;  (** Most places the player may be on after a leg. *)
  max_searched : int;
      (** Most sets of places to search before giving up. The search is over
          sets, not places, so it grows far faster than the map. *)
}

val default : t
(** A tile 1, a wild tile 4 more, a wander tile 3 more, a leg 8, an open stop
    50; open legs off by [1 + n / 5]; tapped; walks along wanderers refused;
    open legs up to 12 tiles, 5 places, 20000 sets searched. *)

val open_leg_error : t -> int -> int
(** How many tiles an open leg of that many tiles may end short or long. *)
