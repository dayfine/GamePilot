(** Reader: a story dialogue box shows, white, blue or teal (the screen's
    [dialog_box] reading). Ported from PokemonLZA_StoryDialogDetector.cpp over
    the three boxes of PokemonLZA_DialogDetector.cpp:

    - white: the box's bottom edge is white (mean summing to 500 at least,
      stddevs to 20 at most); with {!Box_and_arrow}, its black advance arrow
      also shows in the arrow's box (two dark ranges, up to 100 and up to 130);
    - blue: the bottom-right corner is one of two blues (shares within 0.25) and
      the white arrow shows (five grey ranges, from 192 down to 128 up);
    - teal: the teal arrow shows.

    An arrow is a blob of 150 pixels at least matching its template with a score
    under 120 ({!Blob_template}). 01.01's screen reads the white box with
    {!Box_only} (PokemonLZA_AutoStoryScreenEvents.cpp): the box shows while its
    text is still typed. *)

type white_part =
  | Box_and_arrow  (** the white box's edge and its black arrow *)
  | Box_only  (** the white box's edge alone *)

val probes : picture:Wire.box -> assets:Blob_assets.t -> Wire.probe_spec list
(** The probes {!shown} needs, for a game picture at [picture] in the frame. *)

val shown : white:white_part -> Effects.measurements -> bool
(** A white (as [white] asks), blue or teal box shows. [false] for a missing
    probe. *)
