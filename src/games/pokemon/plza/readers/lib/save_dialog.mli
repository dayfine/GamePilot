(** Reader: PLZA's SAVE dialog (R on the main menu), and its "Last Saved" time.
    Ours, measured on console B's capture (2026-11-25, Last Saved 18:16):

    - the dialog: a strip of its white panel (260, 280, 1400, 14), every channel
      200 or over, 1.00 there and 0.67 at most on the other Mystery Gift
      captures (a gift's card), with its dark "Save Progress" button (640, 722,
      640, 56), every channel 110 or under, 0.94 there. The button alone is no
      proof (a black fade or the dimmed gift list fill it); no capture but the
      dialog has both: where the panel strip is white (a white fade, a text box,
      the settings) the button's share is 0.05 at most;
    - "Last Saved": its line (258, 856, 1000, 32), the label, the date and the
      time, short of the Cancel button (1545), dark text on white, as the share
      of each column's (and row's) pixels with every channel under 120. Two
      readings are the same time when their shares differ by 0.3 at most in all.
      The line is read whole, as each language lays it out its own way: the box
      over English's minutes, (552, 856, 70, 32), held French's date (console B,
      2026-11-25: "6/01/2" of 26/01/2026), so a French save never changed it.

    - the current time: its date and time under their label in the top panel
      (690, 356, 380, 60), read the same way (zh-Hans, console B's frame of
      2026-11-26: "2026/01/27 12:12" at x 708 to 1035). It is set in a larger
      type than "Last Saved", and the two are never compared: the current time
      is read for its change only.

    Read before saving and again after, the save counts as done when "Last
    Saved" changed. Measured against a copy of the capture with its last digit
    replaced by the 8 before it (18:18, images/mystery-gift/synthetic-...), as
    no second save was captured: 0.53 to 0.72 apart in every colour shift (18:16
    and 18:18 differ least of the digits; a static dialog read twice on console
    B is 0.00 apart). Also on a copy with the date and time moved where French
    shows them, the date as 26/01/2026 (synthetic-save-dialog-fr-layout-1816 and
    -1818), placed so the old minutes box reads it as console B's French run
    did, but for the day's second digit; no French frame of the dialog was
    captured. Any language whose line fits the box reads the same way; one whose
    date or time sits past x 1258, or on another row, does not. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The panel's, the button's and the two times' probes. *)

val shown : Effects.measurements -> bool
(** The SAVE dialog is open: the panel strip over 0.90 white and the button over
    0.70 dark. *)

val last_saved : Effects.measurements -> float list option
(** The "Last Saved" columns' dark shares, left first; [None] without the
    dialog. *)

val current_time : Effects.measurements -> float list option
(** The current time's columns' and rows' dark shares, as {!last_saved}; [None]
    without the dialog. *)

val same_time : float list -> float list -> bool
(** Two {!last_saved} readings, or two {!current_time} readings, show the same
    time. *)
