(** Where the NPCs' shared RNG is at a given time, and when it will be at a
    given advance: a linear clock anchored on one blink whose advance is known.
    Each NPC tick takes one advance per NPC.

    Port of
    [PokemonBDSP/Programs/RngManipulation/PokemonBDSP_AdvanceClock.{h,cpp}]
    (https://github.com/PokemonAutomation/Arduino-Source; R21: same arithmetic,
    same integer division of advances into ticks). Times are seconds as a
    [float], the unit of the [now] effect, on a grid of whole microseconds: the
    C++ holds a [WallClock] and truncates every duration it adds to one to the
    clock's tick, which is a microsecond with libc++ (the build the golden
    vectors come from), and {!plus_seconds} does the same. Whether a sample at a
    cut-off survives depends on it. Advances and NPC counts are OCaml [int]s
    (the C++ [uint64_t] and [uint8_t]). *)

val plus_seconds : float -> float -> float
(** [plus_seconds time seconds]: [time + duration_cast<WallDuration>(seconds)],
    the duration truncated toward zero to whole microseconds (and [time] snapped
    to the nearest). *)

val seconds_between : earlier:float -> float -> float
(** [later - earlier] in whole microseconds, then in seconds, as
    [duration<double>] of a [WallClock] difference. *)

type t = {
  anchor_time : float;  (** When the anchor blink happened. *)
  anchor_advance : int;  (** The advance of that blink's roll. *)
  tick_seconds : float;
      (** The C++ default is {!Blink_model.npc_tick_seconds}. *)
  npcs : int;  (** Advances per tick; the C++ default is 1. *)
}
(** [AdvanceClock]. *)

val advance_at : t -> float -> int
(** The advance at a time: whole advances since the anchor, at [npcs] per tick,
    truncated; never below 0. *)

val time_of_advance : t -> int -> float
(** The leading edge of the tick holding the advance (not necessarily safe to
    aim at). Advances count in whole ticks ([advance / npcs]). The anchor time
    when [npcs = 0]. *)

val middle_of_advance : t -> int -> float
(** Half a tick before {!time_of_advance}. *)
