(** Reader: a coarse print of the whole picture, the mean color of each cell of
    a 3 by 3 grid, to tell one scene from another. It stands in for the fork's
    whole-frame RMSD where a step must know the screen left a place: Fly's
    [left_departure()] (Programs/AutoStory/PokemonFRLG_AutoStoryFlyLanding). *)

val probes : Wire.probe_spec list

type t
(** The cells' means. *)

val read : Effects.measurements -> t option
(** [None] when a cell's probe is missing. *)

val change : t -> t -> float
(** The cells' channel sums of absolute differences, averaged over the cells: 0
    for the same frame. *)

val min_scene_change : float
(** 40: above it, another scene. From the mGBA save-state shots of 2026-11-21 to
    23 (240 by 160): one place twice differs by 2, two towns or a town and a
    tower by 70 to 165. *)

val left : before:t -> Effects.measurements -> bool
(** The frame shows another scene than [before]: its change is above
    {!min_scene_change}; false when it can't be read. *)
