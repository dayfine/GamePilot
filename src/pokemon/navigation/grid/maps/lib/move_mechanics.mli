(** How each game moves the player for a press, as measured on the console: one
    entry per game, read by that game's walker and by its sim. Times are in
    milliseconds. *)

(** How the walker presses an open leg, one that ends short of a wall. *)
type open_leg_press =
  | Step_taps  (** A step tap a tile: the count is exact. *)
  | Timed_hold  (** One hold, timed by the tile time. *)

type tile_time = { across_ms : int; up_down_ms : int }
(** Time per tile along each axis of the screen: east or west, north or south.
*)

val along : tile_time -> Direction.t -> int
(** The time per tile walking that way. *)

type step_tap = { hold_ms : int; release_ms : int }
(** A tap that takes one step: the press, and the release before the next press.
    Their sum is the time per tapped tile. *)

type gait = { tile : tile_time; tap : step_tap; open_legs : open_leg_press }
(** One way of moving: walking, running or riding. A game's taps differ by gait
    (FRLG's Bicycle taps far faster than its walk). *)

type t = {
  turn_tap_ms : int;  (** A tap that turns the player without a step. *)
  start_delay_ms : int;
      (** From pressing, standing still, to the first step under way. *)
  walk : gait;
  run : gait;  (** B held, once the player has the Running Shoes. *)
  bike : gait option;  (** [None] where the walker does not ride yet. *)
}

val bdsp : t
(** Brilliant Diamond and Shining Pearl, measured on console B. The camera
    tilts, so a row takes longer than a column. D-pad taps move exactly a tile
    each, while a held run overshoots about 3 tiles in 10 (2026-11-09,
    Jubilife), so open legs are tapped. *)

val frlg : t
(** FireRed and LeafGreen, measured on console B: a walking tile is 16 frames,
    running 8, and a held leg stops where its time says, so open legs on foot
    are timed holds; on the Bicycle they are counted in taps, 40 ms at one per
    100 ms (at a 60 ms period one tap in 12 drops). The walker's holds count no
    start delay. *)
