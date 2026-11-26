(** Reader: the money box at the top left (a Mart's MONEY box). The fork's
    Menus/PokemonFRLG_MoneyBoxReader reads its digits and has no presence test;
    this one is new: a white inside with the box's grey frame left of and below
    it. Measured on a Switch capture of the Viridian Mart's BUY list in game
    pixels: frame x 3 to 76, y 2 to 36. The Game Corner's COINS box sits at the
    same place; no capture of it was at hand. *)

val probes : Wire.probe_spec list

(** {1 Thresholds} *)

val frame_min_sum : float
(** The frame's blue grey ((96, 118, 125) on Switch, channel sum 340): channel
    sum from this... *)

val frame_max_sum : float
(** ...to this. *)

(** {1 Reader} *)

val money_box : Effects.measurements -> bool
