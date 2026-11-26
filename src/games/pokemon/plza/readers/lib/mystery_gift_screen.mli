(** Reader: the Mystery Gift screens (main menu, Link Play, Mystery Gift),
    measured on console B (2026-11-20) on the 1080p frame:

    - the gift's card's white header: (0.30, 0.26, 0.40, 0.05), over 0.70 of it
      white (every channel 200 or over, which a capture card 0.9 as bright
      keeps);
    - the bottom text box, dark blue (red under 45, green under 70, blue 66 to
      144): its share of (0.26, 0.80, 0.48, 0.12).

    The card (a gift received) shows when its header does, over 0.70 of its top
    rows (600, 282, 720, 8) are white and the list's items 2 to 6 strips (below)
    are under 0.30 white, the card's dark body; one [core.color_count@1] probe
    reads each box. The top rows tell the card from the list under a question,
    whose header reads 0.70 to 0.71 white (its first item) but whose top edge (y
    279 to 293) is the list's blue: on console B's cards (2026-11-25: the
    English and the Japanese Vivillon's, a 360p capture of the Japanese one, and
    a 360p capture of an item's card) the top rows read 1.00 white and the
    header 0.82 to 0.88 in every shift; on every list, alone or under a
    question, 0.00. The body tells the card from the white fade before it and
    the receive animation's white flashes (every strip 1.00): items 2 to 6 read
    0.07 at most on the cards. The text box is not needed: the item's card
    showed none (0.08 to 0.28 dark blue), Vivillon's 0.68 to 0.95. The Japanese
    card's white title bar covers the first item's strip (0.83 to 0.88 white),
    so that strip says nothing. The SAVE dialog is no card (top rows 1.00,
    header 0.28).

    A question's Yes/No box (console B, Japanese, 2026-11-25: "stop receiving?"
    over the list and "write a report?" over the Mystery Gift menu, the box at
    about (1404, 651, 312, 150)): the highlighted answer's row is white right of
    its word, (1560, 665, 140, 40) for Yes and (1560, 745, 140, 40) for No, 1.00
    white on it and 0.00 on the other; with the text box up, one white and the
    other under 0.30 is the question ({!question}). The "disconnect?" question
    was not captured: it is taken to use the same box.

    The Mystery Gift menu, its first row ("Get with Internet") highlighted:
    white from x 387 to 1521, y 342 to 456, so (1380, 380, 120, 40), right of
    the gift list's right end (1346), reads 1.00 white on it and 0.00 on the
    list, the card and the questions over the list. Its row covers the list's
    second item's strip (1.00 white): without this probe the menu reads as the
    list with its cursor on item 2.

    The list, measured on console B's Internet gift list (2026-11-25, four
    gifts, the cursor on the first): the list's items, 84 pixels apart from y
    295. The selected item is white to its right end: the strip (1010, 310 + 84
    k, 310, 40) is 1.00 white (every channel 200 or over: the item is 253) on
    it, 0.00 on the others and on empty rows. The list is active when exactly
    one item is white (the others under 0.30) and under half the bottom box is
    dark blue. And the gift's name: a template of the name as an unselected item
    shows it (white on grey), matched in each item's name window (576, 554 + 84
    (k - 3), 436, 62). The name scores 0.000 on its own item and 0.088 at least
    on the other three and the empty rows, also shifted (0.003 at most on its
    own). The name is the game language's: on the French list (console B,
    2026-11-25, the same four gifts, "Prismillon (Motif Poké Ball)" at item 4)
    the French template scores 0.000 on its item and 0.070 at least elsewhere,
    shifted too (0.003 at most on its own), and the English one 0.092 at least
    everywhere. Likewise the Japanese template ("ボールのもようの　ビビヨン" at item 4 of the
    Japanese list under "stop receiving?", console B, 2026-11-25, cut as the
    others at (592, 566, 400, 38)): 0.000 on its item (0.003 at most shifted)
    and 0.078 at least elsewhere, shifted too. And the zh-Hans template
    ("球球花纹的彩粉蝶" at item 4 of the zh-Hans list, console B, 2026-11-26, cut the
    same way). The French list's third name is long enough to reach that item's
    strip: 0.14 white. *)

val items : int
(** 6: the rows the list shows. *)

val probes : picture:Wire.box -> gift_name:string option -> Wire.probe_spec list
(** The card's, the items' and the gift name's probes, for a game picture at
    [picture] in the frame; [gift_name] the name template's reference, in the
    game's language. Without one the name is not matched ({!gift_item} is
    [None]). *)

val selected_item : Effects.measurements -> int option
(** The one white item, 0 the top; [None] when none or several are. *)

val list_active : Effects.measurements -> bool
(** The gift list, waiting for a choice. [false] for a missing probe, and on the
    Mystery Gift menu and a card (an item's card reads as the list with its
    first item selected otherwise). *)

val list_shown : Effects.measurements -> bool
(** The gift list (an item white), whatever is over it: A there could claim a
    gift. [false] on the Mystery Gift menu. *)

val gift_menu : Effects.measurements -> bool
(** The Mystery Gift menu, its first row highlighted. *)

val text_up : Effects.measurements -> bool
(** The bottom text box (a message or a question) shows: over 0.60 of it dark
    blue. *)

(** A question's highlighted answer. *)
type answer = Yes  (** Yes highlighted. *) | No  (** No highlighted. *)

val question : Effects.measurements -> answer option
(** A Yes/No question with the text box up, and its highlighted answer. *)

val message : Effects.measurements -> bool
(** A message in the text box, no question, card or gift list under it (the
    Mystery Gift menu may be): A only moves past it. *)

val gift_item : Effects.measurements -> int option
(** The item showing the gift's name (scored 0.05 at most, the best), when the
    cursor is not on it. *)

val card : Effects.measurements -> bool
(** A gift's card, with its text box or without: the gift was received. *)

val describe : Effects.measurements -> string
(** The items' white shares, the name scores and the card's shares, for a log
    line. *)
