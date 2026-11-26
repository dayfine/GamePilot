(** Shares of a box's pixels within a colour range, read from one
    [core.color_count@1] probe, as the PLZA readers measure them in frame pixels
    ({!Native_box}). Ours: the fork's PLZA readers count pixels with their own
    loops (PokemonLZA_PixelShares.cpp slides a box; these boxes stay put). *)

type range = { low : int * int * int; high : int * int * int }
(** Each channel's least and most value, both included, red then green then
    blue. *)

val white : int -> range
(** Every channel at least the value, up to 255. *)

val dark : int -> range
(** Every channel at most the value, from 0. *)

val probe :
  picture:Wire.box -> id:string -> Native_box.t -> range -> Wire.probe_spec list
(** A [core.color_count@1] probe over the box, every frame; none when the box is
    not wholly in the picture. *)

val share : Effects.measurements -> string -> float option
(** The probe's share, 0 to 1, when there is one
    ({!Switch_home.Color_share.read}). *)
