(** The encounter rate tables: how a roll from 0 to 99 maps to a slot.

    The thresholds of [slot_number_from_roll] in the fork's
    [Pokemon/Pokemon_AdvRng.cpp], one list per table where the C++ has one
    if-chain: a roll picks the first slot whose threshold it is below. *)

val thresholds : size:int -> super_rod:bool -> int list
(** For a table of [size] slots: 12 (grass), 5 (surfing and Rock Smash, or the
    Super Rod with [super_rod]), 3 (Good Rod), 2 (Old Rod); [[]] (always slot 0)
    for any other size. *)
