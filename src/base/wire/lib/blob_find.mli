(** The params and blobs of [core.find@1] (protocol v1.13): the fork's fixed
    pipeline (colour filter, 4-connected blobs as its waterfill finds them, size
    filter, scores), as CommonTools/Images/WaterfillUtilities.cpp's
    match_template_by_waterfill and CommonTools/ImageMatch's
    WaterfillTemplateMatcher with ExactImageMatcher run it. Sizes are game
    pixels; the daemon judges nothing. *)

type json = Yojson.Safe.t

type filter = { low : int * int * int; high : int * int * int }
(** One colour range, (r, g, b) 0..255 each, both ends included: a mask of its
    own, as each of the fork's FILTERS. *)

type params = {
  filters : filter list;  (** non-empty, searched in order *)
  min_area : float;  (** a blob's pixels, at least 1 *)
  max_area : float option;  (** a blob's pixels, at most *)
  min_size : (float * float) option;  (** width, height; both ends included *)
  max_size : (float * float) option;
  margin : float option;  (** asks for each blob's [stray] *)
  shape : string option;
      (** an uploaded PNG's hash; asks for each blob's [overlap]. A template
          asking for [score] is the probe's own [template]. *)
  masked : bool;
      (** (v1.15) score each blob's box with the pixels outside the filter's
          range black, as the fork's [filter_by_mask] before
          MoveEffectivenessSymbol's match; [false] scores the box as it is *)
}
(** What a [core.find@1] probe asks the daemon for: the filters, the size
    bounds, and which scores to give each blob. *)

type blob = {
  filter : int;  (** the index of the filter that made it *)
  x : float;  (** its bounding box, game pixels of the picture *)
  y : float;
  w : float;
  h : float;
  fill : float;  (** its pixels over its box's (the fork's area_ratio) *)
  stray : float option;
      (** with a margin: the filter's other pixels within it, over its pixels *)
  score : float option;
      (** with a template: ExactImageMatcher::rmsd of its box, lower is better
      *)
  overlap : float option;
      (** with a shape: its pixels and the shape's, both over either *)
}
(** One blob the daemon found, in game pixels of the picture, with the scores
    the params asked for. *)

val params :
  ?max_area:float ->
  ?min_size:float * float ->
  ?max_size:float * float ->
  ?margin:float ->
  ?shape:string ->
  ?masked:bool ->
  filters:filter list ->
  min_area:float ->
  unit ->
  (params, string) result
(** The params, or why the daemon would refuse them: no filter, a range whose
    low end is above its high end or outside 0..255, [min_area] below 1 or above
    [max_area], a negative size or margin. *)

val params_of_json : string -> json -> params
(** From the probe object; [what] names it in a [Decode_error]. *)

val params_fields : params -> (string * json) list
(** The probe object's fields for these params. *)

val of_json : string -> json -> blob list
(** A result object's [blobs]; [what] names it in a [Decode_error]. *)

val to_json : blob list -> json
(** The result object, [kind] included. *)
