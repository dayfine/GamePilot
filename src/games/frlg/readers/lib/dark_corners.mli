(** Reader: black corners around a lit middle. Ported from the fork's
    [dark_cave_screen] (Overworld/PokemonFRLG_OverworldWalk), which looks for a
    dark cave before Flash; it also holds on a small room or a map's edge with
    black around it, and on the Game Freak logo. On all of these the black below
    would pass for a battle's text box, so {!Screen_facts} reads nothing else
    there. Corners: 2 by 2 tiles of the picture; middle: the player's tile. *)

val probes : Game_screen.t -> Wire.probe_spec list

(** {1 Thresholds} *)

val max_corner_sum : float
(** Each corner's channel sum is below this: black. *)

val min_middle_sum : float
(** The middle is lit: its channel sum is at least this. *)

(** {1 Reader} *)

val dark_corners : Effects.measurements -> bool
(** All four corners black and the middle lit. *)
