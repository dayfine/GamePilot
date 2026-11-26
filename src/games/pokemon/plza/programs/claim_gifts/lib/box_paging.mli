(** From the box the Boxes open on (the one last looked at, console B,
    2026-11-26: Box 8) to Box 1 and back, by L and R (80 ms, released 800, the
    fork's box change in PokemonLZA_BoxSorter.cpp less its video delay), each
    followed by the box title held the same 1 s within 3 s
    ({!Plza_readers.Box_title}). Ours: the fork's box programs start on the box
    the user picked.

    L goes down one box, and from Box 1 round to the last ("Box 32"): the one L
    whose title inks a digit wider than the one before it
    ({!Plza_readers.Box_title.one_more_digit}). So L is pressed until the title
    widens so, up to 40 times, and R once back: Box 1, whatever box the Boxes
    opened on. The Ls before it count the boxes back to the open one. The titles
    of boxes 1 to 9 are as wide, so only that count tells them apart: the way
    back to the open box, and to Box 1 again, is pressed by it and its title
    checked for width only.

    Box names must be the game's own and there must be ten boxes or more (PLZA
    has at least ten); that L goes round from Box 1 to the last is ours, as the
    Boxes of the other Switch Pokémon games do, not yet run on a console. The
    cursor must be off the box's first row, whose name tag covers the title. *)

type t
(** The box the Boxes opened on and Box 1, by their titles and the Ls between
    them. *)

val to_box_one : log:(string -> unit) -> (t, string) result
(** On the Boxes, to Box 1. [Error] when a title does not read, the title never
    widens or R does not come back to a title as wide as Box 1's. *)

val opened_on : t -> int
(** The number of the box the Boxes opened on. *)

val to_opened : t -> (unit, string) result
(** From Box 1 to the box the Boxes opened on: R that many times. [Error] when
    its title does not read as wide as it did. *)

val back_to_box_one : t -> (unit, string) result
(** From the box the Boxes opened on to Box 1: L that many times. [Error] when
    its title does not read as wide as Box 1's. *)
