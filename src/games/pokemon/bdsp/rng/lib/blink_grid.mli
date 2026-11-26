(** Every watcher's blink events placed on one grid of advances: the watched
    rolls {!State_solver} reads, and anchors for the advance of a later blink.

    Port of the second half of the fork's
    [PokemonBDSP/Inference/Rng/PokemonBDSP_BlinkExtraction.{h,cpp}]
    ([assign_tick_indices], [build_samples], [last_blink_anchor],
    [step_blink_anchor]; R21: same origin, same rounding, same messages); the
    first half is {!Blink_extraction}. A [false] return with out-parameters
    becomes a [result] or an option. Advances, slots and NPC counts are OCaml
    [int]s (the C++ narrows the stream count to 8 bits). *)

val build_samples :
  Blink_extraction.blink_event list list ->
  slots:int list ->
  period_seconds:float ->
  (State_solver.blink_sample list, string) result
(** Places every watcher's events on one tick grid, anchored at whichever
    watcher blinked first, and lists every roll from that tick to the last as a
    watched sample ([advance = tick * npcs + slot], [npcs] being the number of
    streams), sorted by advance. [slots.(s)] is stream [s]'s place in the NPCs'
    order. [Error] names the problem, as the C++'s [failure_reason]. *)

type anchor = {
  advance : int;  (** The blink's roll on the {!build_samples} grid. *)
  seconds : float;  (** When the blink was seen. *)
  stream_index : int;  (** The watcher that saw it, counted from 0. *)
}
(** A blink tied to its advance, which later blinks are counted from: the three
    out-parameters of the C++ [last_blink_anchor]. *)

val last_blink_anchor :
  Blink_extraction.blink_event list list ->
  slots:int list ->
  period_seconds:float ->
  anchor option
(** The latest blink of any stream, with its advance on the grid
    {!build_samples} uses; an earlier stream wins a tie. *)

val step_blink_anchor :
  elapsed_seconds:float ->
  period_seconds:float ->
  npcs:int ->
  previous_advance:int ->
  int option
(** Moves an anchor forward onto a later blink from the same stream: the elapsed
    time rounded to whole ticks, times [npcs]. [None] (the C++ leaves the
    advance unchanged) unless that is at least one tick. *)
