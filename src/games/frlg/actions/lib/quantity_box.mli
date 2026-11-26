(** The quantity box a Mart's BUY and the PC's WITHDRAW ITEM ask how many with:
    pokefirered ([ce6406d]) menu_helpers.c [AdjustQuantityAccordingToDPadInput].
    It starts at 1; UP adds one and wraps from the most to 1, DOWN takes one and
    wraps from 1 to the most, RIGHT adds ten and LEFT takes ten, stopping at the
    most and at 1.

    {!presses_from_one} is ported from the fork's AutoStory Mart
    (Programs/AutoStory/PokemonFRLG_AutoStoryMart), unchanged; {!next_press}
    is new, not in the fork, which never withdraws an item. *)

val tens : int
(** 10: what RIGHT and LEFT move. *)

val presses_from_one : int -> int * int
(** [(right, up)] from 1 to the quantity: RIGHT never passes it, so it never
    stops at the most. *)

val next_press : now:int -> target:int -> most:int -> Wire.button option
(** The press that moves the box from [now] toward [target] (in 1 .. [most]):
    DOWN from 1 straight to the most when that is the target, RIGHT or LEFT
    while ten or more away, UP or DOWN for the rest; [None] at the target. *)
