(** Reader: where the player stands, told by the picture, for the console's
    start check: the GBA screen's 15 by 10 tiles of 16 pixels, each tile's mean
    color, kept when the runner saves at a checkpoint's start and compared with
    the frame after that save is loaded. Ported from the fork's
    AutoStory/PokemonFRLG_AutoStoryStartFrames and StartFrameCompare
    ([frlg/lean]): a tile has changed when its color differs by more than
    {!tile_change} on average per channel, and the place is the same when at
    most {!most_changed_percent} of the tiles changed (room for people who
    walked).

    Where it differs: the fork compares each tile's four 8x8 quarters and also
    its detail (each pixel less its surroundings, shifted up to 2 pixels), which
    lets Pokemon Tower's moving fog pass; here the daemon gives each tile's mean
    alone (a [core.color_stats@1] probe per tile), so a fogged floor can read as
    another place. *)

val columns : int
(** 15. *)

val rows : int
(** 10. *)

val probes : Wire.probe_spec list
(** One color-stats probe per tile, row by row. *)

type t
(** Each tile's mean color, row by row. *)

val read : Effects.measurements -> t option
(** [None] when a tile's probe is missing. *)

type difference = { tiles : int; changed : int }

val compare : reference:t -> t -> difference

val tile_change : float
(** 24: the fork's [TILE_CHANGE], per channel, 0..255. *)

val most_changed_percent : int
(** 25: the fork's [MOST_CHANGED_PERCENT]. *)

val same_place : difference -> bool

val difference_to_string : difference -> string
(** ["12 of 150 tiles changed"]. *)

val to_json : t -> Yojson.Safe.t
(** [{"tiles": [[r, g, b], ...]}], row by row. *)

val of_json : Yojson.Safe.t -> (t, string) result
