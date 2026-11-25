(** Reader: PLZA's Boxes screen (main menu row 0, Boxes) is open. Ours, measured
    on console B's capture (2026-11-25: Xerneas in Box 1, the party full): the
    white tab at the top left ("X", the box icons) is all white over (130, 30,
    110, 36), every channel 200 or over, while the "Current Party" title band
    under it (100, 100, 240, 40), dark blue, is not (a white fade is white in
    both). The lab script read nothing there; the steps read it to tell the
    Boxes from the first-time "Your Boxes" card ({!Plza_gifts.Gift_to_box}). *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The tab's probe, for a game picture at [picture] in the frame. *)

val shown : Effects.measurements -> bool
(** The tab is over 0.80 white and the party's title band under 0.05 (0.00 on
    the Boxes; 0.17 on a controls hint with a white top left). *)
