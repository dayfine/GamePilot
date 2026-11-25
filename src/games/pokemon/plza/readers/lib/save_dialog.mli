(** Reader: PLZA's SAVE dialog (R on the main menu), and its "Last Saved" time.
    Ours, measured on console B's capture (2026-11-25, Last Saved 18:16):

    - the dialog: a strip of its white panel (260, 280, 1400, 14), every channel
      200 or over, 1.00 there and 0.67 at most elsewhere (a gift's card), with
      its dark "Save Progress" button (640, 722, 640, 56), every channel 90 or
      under, 0.93 there and 0.35 at most elsewhere (the Boxes);
    - "Last Saved": its date and time (405, 856, 220, 32), dark text on white,
      as the share of each column's pixels with every channel under 120. Two
      readings are the same time when no column differs by more than 0.2.

    The script did not read the save. The steps read the dialog before saving
    and again after, and count the save done when "Last Saved" changed
    ({!Plza_gifts.Gift_to_box}). Measured against a copy of the capture with its
    last digit replaced by the 8 before it (18:18,
    images/mystery-gift/synthetic-...), as no second save was captured. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The panel's, the button's and the time's probes. *)

val shown : Effects.measurements -> bool
(** The SAVE dialog is open: the panel strip over 0.90 white and the button over
    0.70 dark. *)

val last_saved : Effects.measurements -> float list option
(** The "Last Saved" columns' dark shares, left first; [None] without the
    dialog. *)

val same_time : float list -> float list -> bool
(** Two {!last_saved} readings show the same time. *)
