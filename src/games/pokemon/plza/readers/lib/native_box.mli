(** A box in the pixels of a 1920x1080 frame, where the fork's PLZA readers are
    measured. A box the fork gives as fractions of the frame is cropped as the
    fork crops it (CommonFramework/ImageTools/ImageBoxes.cpp): left, top, width
    and height each times the frame's size, plus a half, truncated. The probe
    box has these pixel edges exactly, so the daemon (which rounds both edges)
    reads the same pixels. A slid box moves by whole pixels. *)

type t = { x : int; y : int; w : int; h : int }
(** Left, top, width and height in pixels of a 1920x1080 frame. *)

type fractions = { left : float; top : float; width : float; height : float }
(** A box as fractions of the frame, as the fork writes it. *)

val frame_width : int
(** 1920. *)

val frame_height : int
(** 1080. *)

val of_fractions : fractions -> t
(** The pixels the fork crops for this box. *)

val shifted : ?dx:int -> ?dy:int -> t -> t
(** Moved right by [dx] and down by [dy] pixels (default 0). *)

val probe_box : picture:Wire.box -> t -> Wire.box option
(** The box relative to the game picture at [picture] in the frame (the
    [hello]'s viewport; the whole frame on [native]), or [None] when it is not
    wholly inside ({!Switch.Picture_box.whole}). *)
