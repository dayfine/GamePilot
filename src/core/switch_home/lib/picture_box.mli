(** The fork's boxes, normalized to the whole 1920x1080 frame
    (CommonFramework/ImageTools/ImageBoxes.h), as probe boxes, which the daemon
    takes relative to the game picture: the viewport its [hello] reports
    (Wire.backend's [viewport]). On the native viewport (the picture is the
    frame) a box is the fork's unchanged; on the GBA app's ([nso-gba]) it is
    clipped to the picture. *)

val clipped : picture:Wire.box -> Wire.box -> Wire.box option
(** The box's part inside the picture, relative to the picture; [None] when no
    part is inside. *)

val whole : picture:Wire.box -> Wire.box -> Wire.box option
(** The box relative to the picture when it lies wholly inside, else [None]: for
    a box whose content a clip would cut away. *)
