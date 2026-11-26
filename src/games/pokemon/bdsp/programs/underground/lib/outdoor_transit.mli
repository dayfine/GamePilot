(** Outdoor-to-Underground entry (Fly to Oreburgh City + Explorer Kit) and
    Underground-to-surface exit for [bdsp.underground].

    Starting from any outdoor Sinnoh location, {!ensure_in_underground} checks
    {!Bdsp_readers.Underground_screen.t.in_underground}; if on the surface, it
    opens the Town Map, clamps to the top-left corner, flies to Oreburgh City
    (which drops directly into the Central Grassland Cave farming hallway), and
    dives offline via the registered Explorer Kit on the [+] shortcut wheel.
    When farming completes, {!leave_underground} returns to the surface via
    [Y -> Down -> A -> A]. *)

val ensure_in_underground :
  log:(string -> unit) -> picture:Wire.box -> unit -> (unit, string) result
(** Ensure the player is inside the Grand Underground, flying to Oreburgh City
    and diving with the Explorer Kit if currently outdoors on the surface. *)

val home_to_south_door : log:(string -> unit) -> unit
(** Wall-clamp run ([N -> E -> S -> W]) from anywhere in the Central Grassland
    Cave hallway ring back to the South Hideaway doorway. *)

val leave_underground :
  log:(string -> unit) -> picture:Wire.box -> unit -> (unit, string) result
(** Return from the Grand Underground to the Sinnoh surface via the [Y] menu. *)
