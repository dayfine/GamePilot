(** Boxes in the pixels of the 1920x1080 frame, as Pokémon HOME's readers are
    measured, and their probes on the whole frame (the daemon's [native]
    viewport, the only one HOME is read on), with the probe results they read.
*)

type t = { x : int; y : int; w : int; h : int }
(** Left, top, width and height in frame pixels. *)

val box : t -> Wire.box
(** The box normalized to the frame. *)

val stats_probe : string -> t -> Wire.probe_spec
(** A [core.color_stats@1] probe, every frame. *)

val count_probe :
  string -> t -> min:int * int * int -> max:int * int * int -> Wire.probe_spec
(** A [core.color_count@1] probe, every frame. *)

val template_probe :
  ?ink:Wire.color_range ->
  string ->
  t ->
  Effects.template_hash ->
  Wire.probe_spec
(** A [core.template_match@1] probe, every frame. *)

val score : Effects.measurements -> string -> (float * float) option
(** A [template_match] probe's score and its placement's left edge in frame
    pixels. *)
