(** From the box the Boxes open on (the one last looked at; console B,
    2026-11-26: Box 8) to Box 1: the box title read, held the same 1 s within 3
    s ({!Plza_readers.Box_title}), and L (80 ms, released 800, the fork's box
    change in PokemonLZA_BoxSorter.cpp less its video delay) while it does not
    name Box 1, up to 32 times. L goes down a box, and from Box 1 round to the
    last (console B, 2026-11-26: 8 boxes, Box 1 then Box 8). Ours: the fork's
    box programs start on the box the user picked.

    The cursor must be off the box's first row, whose name tag covers the title.
    The probes must be subscribed ({!Mystery_gift.probes}). *)

val to_box_one : log:(string -> unit) -> (unit, string) result
(** On the Boxes, to Box 1, its title read as Box 1 last. [Error] when a title
    does not read, or none names Box 1 after 32 L. *)
