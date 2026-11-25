(** Reader: the Mystery Gift screens (main menu, Link Play, Mystery Gift) as
    [plza_claim_and_bank.sh] in the BDSPLab lab tools reads them (console B,
    2026-11-20), its [mg_list_active] and [mg_card] tests on the 1080p frame:

    - the gift's card's white header: (0.30, 0.26, 0.40, 0.05), over 0.70 of it
      white (every channel over 230);
    - the bottom text box, dark blue (red under 45, green under 70, blue 66 to
      144): its share of (0.26, 0.80, 0.48, 0.12).

    The card (a gift received) shows when its header does and over 0.60 of the
    bottom is dark blue. The script read them with numpy; here one
    [core.color_count@1] probe a box.

    New here, measured on console B's Internet gift list (2026-11-25, four
    gifts, the cursor on the first): the list's items, 84 pixels apart from y
    295. The selected item is white to its right end: the strip (1010, 310 + 84
    k, 310, 40) is 1.00 white (every channel 200 or over: the item is 253) on
    it, 0.00 on the others and on empty rows. The script's list test was the top
    bar (0.32, 0.28, 0.36, 0.05) white, which is the first item selected, and a
    white fade or text box passed it; here the list is active when exactly one
    item is white (the others under 0.30) and under half the bottom box is dark
    blue. And the gift's name: a template of the name as an unselected item
    shows it (white on grey), matched in each item's name window (576, 554 + 84
    (k - 3), 436, 62); the script took the 4th item by its place. The name
    scores 0.000 on its own item and 0.088 at least on the other three and the
    empty rows, also shifted (0.003 at most on its own). The card's tests are
    the script's, untested here (no capture of a card yet). *)

val items : int
(** 6: the rows the list shows. *)

val probes : picture:Wire.box -> gift_name:string -> Wire.probe_spec list
(** The card's, the items' and the gift name's probes, for a game picture at
    [picture] in the frame; [gift_name] the name template's reference. *)

val selected_item : Effects.measurements -> int option
(** The one white item, 0 the top; [None] when none or several are. *)

val list_active : Effects.measurements -> bool
(** The gift list, waiting for a choice. [false] for a missing probe. *)

val gift_item : Effects.measurements -> int option
(** The item showing the gift's name (scored 0.05 at most, the best), when the
    cursor is not on it. *)

val card : Effects.measurements -> bool
(** A gift's card with its text box: the gift was received. *)

val describe : Effects.measurements -> string
(** The items' white shares, the name scores and the card's shares, for a log
    line. *)
