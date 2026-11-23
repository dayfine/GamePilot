(** Where the GBA picture sits in a frame. Reader boxes are relative to the game
    picture; this maps them to the frame the daemon sees, which differs by
    backend: mGBA frames are the 240x160 picture itself, while a Switch capture
    has the picture inside black side bars. *)

type t = Wire.box
(** The game picture's box in the frame, normalized. *)

val whole_frame : t
(** mGBA: the frame is the picture. *)

val switch_capture : t
(** A Switch capture card frame: the fork's default FRLG [GAME_BOX]
    (PokemonFRLG_Settings.cpp), the picture inside its pillarbox. *)

val box : t -> Wire.box -> Wire.box
(** [box screen b] is the frame box of [b], a box relative to the picture. *)

val color_stats_probe : t -> id:string -> Wire.box -> Wire.probe_spec
(** A [core.color_stats@1] probe over a picture-relative box, every frame. *)
