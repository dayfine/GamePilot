(** Shares of a box's pixels passing a colour test, read from one
    [core.line_shares@1] probe as the fork's PLZA readers count them
    (PokemonLZA_PixelShares.cpp). The fork slides a box a few pixels at a time
    and counts each position again; here one probe spans every position along
    the slide, and a position's share is the mean of its rows' (or columns')
    shares, each line being as long as the box. *)

val sky_blue : Wire.Line_shares.test
(** The controls hint's sky blue: blue over 200, green over 160, blue over red
    by 60 (PokemonLZA_ControlsHintDetector.cpp). *)

val cyan : Wire.Line_shares.test
(** Bright cyan glow: blue over red by 50, green over red by 30, blue over 120,
    blue at least green less 20 (which keeps out mint and sign green). *)

val dim_cyan : Wire.Line_shares.test
(** Dimmer cyan glow, over dark scenes: red margins 40 and 25, blue over 70. *)

val white : Wire.Line_shares.test
(** Bright white: every channel over 200. *)

val probe :
  picture:Wire.box ->
  id:string ->
  Native_box.t ->
  Wire.Line_shares.test ->
  Wire.probe_spec list
(** A [core.line_shares@1] probe over the box, every frame; none when the box is
    not wholly in the picture. *)

val lines : Effects.measurements -> string -> Wire.Line_shares.t option
(** The probe's rows and columns, when there are any. *)

val window : float list -> first:int -> count:int -> float option
(** The mean of [count] lines from line [first] (0 the first): the share of a
    box that many lines long there. [None] when they are not all in the list. *)
