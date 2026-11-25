(** Reader: the Mystery Gift screens (main menu, Link Play, Mystery Gift) as
    [plza_claim_and_bank.sh] in the BDSPLab lab tools read them (console B,
    2026-11-20), its [mg_list_active] and [mg_card] tests on the 1080p frame:

    - the white top bar of the gift list or the gift's card: the box (0.32,
      0.28, 0.36, 0.05), over 0.70 of it white (every channel over 230); the
      card's header (0.30, 0.26, 0.40, 0.05), likewise;
    - the bottom text box, dark blue (red under 45, green under 70, blue 66 to
      144): its share of (0.26, 0.80, 0.48, 0.12).

    The list is active when its top bar shows and under half the bottom box is
    dark blue; the card (a gift received) when its header shows and over 0.60 of
    the bottom is dark blue. The script read them with numpy; here one
    [core.color_count@1] probe a box.

    No capture of these screens survives: the boxes and limits are the script's,
    untested here. A white fade reads as the active list (its top bar white, no
    blue box), so a reading is taken only once it has held a while
    ({!Plza_gifts.Mystery_gift}). *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The three boxes' probes, for a game picture at [picture] in the frame. *)

val list_active : Effects.measurements -> bool
(** The gift list, waiting for a choice. [false] for a missing probe. *)

val card : Effects.measurements -> bool
(** A gift's card with its text box: the gift was received. *)

val describe : Effects.measurements -> string
(** The four shares, for a log line. *)
