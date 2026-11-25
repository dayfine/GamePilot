(** Whether a [core.find@1] blob is a template's shape, as the fork matches a
    template to a blob (CommonTools/ImageMatch/WaterfillTemplateMatcher.cpp,
    CommonTools/Images/WaterfillUtilities.cpp): its aspect against the
    template's, its fill against the template's, then the daemon's score (the
    root mean square colour difference from the template) under a limit. The
    template is the crop the fork makes from its Packages image, kept in
    assets/templates with its size and fill in templates.json (written by
    assets/extract/write_find_templates.py). *)

type t = {
  width : int;  (** the crop's size, pixels *)
  height : int;
  fill : float;  (** the crop's shape pixels over its box's *)
  aspect_lower : float;
      (** bounds on the template's width times the blob's height over the
          template's height times the blob's width *)
  aspect_upper : float;
  fill_lower : float;  (** bounds on the blob's fill over the template's *)
  fill_upper : float;
}
(** One template with the bounds a reader allows it. *)

val matches : t -> max_score:float -> Wire.Blob_find.blob -> bool
(** The blob's aspect and fill are within bounds and its score is under
    [max_score]; [false] without a score. *)
