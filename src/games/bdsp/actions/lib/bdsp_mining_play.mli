(** Live Switch execution of the BDSP 13x10 Grand Underground mining minigame,
    connecting {!Bdsp_readers.Mining_grid} to
    {!Bdsp_underground.Mining_solver.decide}. *)

open Bdsp_underground

val toggle_mining_tool : unit -> unit
(** Press R in the mining minigame to switch between Pickaxe and Hammer. *)

val mining_move_cursor : dx:int -> dy:int -> unit
(** Move the 13x10 mining grid cursor by [(dx, dy)] tiles. *)

val mining_strike : unit -> unit
(** Strike the current mining grid tile with A and wait for the hit animation.
*)

val dig_wall_smart :
  log:(string -> unit) ->
  picture:Wire.box ->
  goal:Mining_goal.goal ->
  tally:Mining_goal.tally ->
  unit ->
  (int * bool, string) result
(** Play an open 13x10 mining wall live using {!Bdsp_readers.Mining_grid} and
    {!Bdsp_underground.Mining_solver.decide} until the wall collapses or
    finishes. Returns [(moves_taken, bailed)]. *)
