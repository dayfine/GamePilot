(** How BDSP turns Xorshift128 rolls into blinks: an NPC's blink per tick and a
    Pokemon model's seconds between blinks, plus the inverse (which rolls fit a
    measured interval) that the state solver reads.

    Port of
    [PokemonBDSP/Programs/RngManipulation/PokemonBDSP_BlinkModel.{h,cpp}]
    (https://github.com/PokemonAutomation/Arduino-Source; R21: same constants,
    same float steps). Each float operation is rounded as written, as in the x86
    and MSVC builds of the C++. Compilers for arm64 fuse [range_float]'s
    multiply-add into one FMA unless told not to (the fork's clang build does,
    and so would ocamlopt), which can move the result by one ulp; this port
    keeps the products separate. Rolls are 32-bit values held in an OCaml [int];
    floats are IEEE doubles as in the C++. Precondition failures return [Error]
    where the C++ throws [InternalProgramError]. *)

val npc_tick_seconds : float
(** 1.017: seconds per NPC tick, one advance per NPC. *)

val pokemon_blink_min_seconds : float
(** 3.0: the low end of the range a Pokemon model's blink interval is drawn
    from, before {!pokemon_blink_offset_seconds}. *)

val pokemon_blink_max_seconds : float
(** 12.0: the high end of that range. *)

val pokemon_blink_offset_seconds : float
(** 0.285: seconds added to every drawn interval, so a Pokemon blinks every
    3.285 to 12.285 seconds. *)

type blink_type =
  | Single
  | Double  (** Whether an NPC closes its eyes once or twice in one blink. *)

val blink_type_name : blink_type -> string
(** ["Single"] or ["Double"], as the C++ prints them. *)

val npc_blinks : int -> bool
(** An NPC blinks when bits 1-3 of its roll are all zero: about 1 in 8. *)

val npc_blink_type : int -> blink_type
(** Bit 0 decides single or double. *)

val range_float : int -> minimum:float -> maximum:float -> float
(** The game's float generator: the roll's low 23 bits over [2^23 - 1]. It runs
    backwards: a zero roll gives [maximum], all ones [minimum]. *)

val pokemon_blink_interval : int -> float
(** Seconds until a Pokemon model's next blink. *)

val pokemon_blink_known_bits : int
(** 4: the top bits of the fraction a measured interval pins down. *)

val pokemon_blink_fraction : float -> int option
(** The 23-bit fraction behind a measured interval; [None] when no roll could
    give it (including NaN). *)

val pokemon_blink_bucket_with_margin : float -> (int * float) option
(** The top {!pokemon_blink_known_bits} of the fraction, and the seconds of
    timing error the reading could absorb before flipping to a neighbouring
    bucket (capped by the distance to either end of the range). [None] only when
    no roll could give the interval. *)

type blink_tick = { blinked : bool; blink_type : blink_type }
(** [blink_type] means something only when [blinked]. *)

val generate_blink_ticks :
  Xorshift128.state ->
  ticks:int ->
  npcs:int ->
  slot:int ->
  (blink_tick list, string) result
(** One NPC's blinks over [ticks] ticks, when [npcs] NPCs each take one advance
    per tick and the watched one is at [slot] in that order. [Error] when
    [npcs = 0] or [slot >= npcs]. *)
