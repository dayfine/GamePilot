# Mystery Gift captures, redacted

Console B's captures (2026-11-25; the synthetic-* ones are edited copies),
each redacted to what its own reader probes by
`dev/reader_fixtures/redact_frame.py`, so no party, box, summary or trainer
detail is kept: everything outside the kept probes' boxes is flat mid-grey.
The probe spec is `write_probe_spec.exe --gifts en` (run from `src/`); each in
place (IN and OUT the same file):

    redact_frame.py SPEC '^(boxes_screen|box_cell)\.' boxes-xerneas-in-box-1.png
    redact_frame.py SPEC '^(boxes_screen|box_cell|box_title)\.' boxes-box-[138]-ja-360p.png
    redact_frame.py SPEC '^(mystery_gift|received_before)\.' *-before-ja-360p.png
    redact_frame.py SPEC '^mystery_gift\.(card_header|text_box)' card-vivillon.png
    redact_frame.py SPEC '^mystery_gift\.' claim-white-fade.png gift-list-*.png
    redact_frame.py SPEC '^save_dialog\.' *save-dialog*.png

The Japanese ones (`*-ja*`, from `--gifts ja`) keep every `^mystery_gift\.`
probe: `card-vivillon-ja.png` is console B's 1080p capture of the card
received on 2026-11-25 (the gift's card, its text and the date and time
only); the `*-360p.png` frames are that run's and the one before's 640x360
frames, saved as PNG.

The SAVE dialog keeps its "Last Saved" date and time: the reader reads them.

`boxes-box-8-ja-360p.png` is the 640x360 frame of console B's claim-gifts run
of 2026-11-26 on the Boxes (Box 8, "ボックス8", Xerneas under the cursor),
saved as PNG: the Boxes' tab, the cell's panel ends and the box title only.

`boxes-box-1-ja-360p.png` and `boxes-box-3-ja-360p.png` are frames 286 and
283 of console B's claim-gifts run of 2026-11-26 (the second), L paging the
boxes (Box 1, Box 3, empty cells under the cursor), redacted the same way.

`gift-received-before-ja-360p.png` is frame 49 of console B's claim-gifts run
of 2026-11-26 (the first): the message after Vivillon's claim that it was
received before. `code-used-before-ja-360p.png` is frame 126 of the second:
the message after `CELEBRATE30TH`'s + that the code was used. Each keeps the
gift screens' probes and the messages' template windows only. The templates
in `../../../assets/` (`gift-received-before-ja.png`,
`code-used-before-ja.png`) are a line of each, cut from the unredacted frames
and scaled 3 times up (`Received_before` gives the boxes).

`save-dialog-zh-hans-1212-360p.png` is frame 189 of console B's claim-gifts
run of 2026-11-26 (the third, zh-Hans): the SAVE dialog, its current time and
"Last Saved" both 2026/01/27 12:12, redacted to `^save_dialog\.`.
`synthetic-save-dialog-zh-hans-1211-360p.png` is its copy with the current
time's last "2" replaced by the "1" before it (12:11), as no second minute
was captured.

`gift-list-zh-hans-cursor-on-1.png` is console B's 1080p capture of the zh-Hans
Internet gift list (2026-11-26, four gifts, the cursor on the first, Vivillon
the 4th as "球球花纹的彩粉蝶"), redacted to `^mystery_gift\.`. Vivillon's
zh-Hans name template (`../../../assets/gift-name-vivillon-poke-ball-zh-Hans.png`)
is cut from the unredacted capture at (592, 566, 400, 38), as the others.

`save-dialog-zh-hans-1223.png` is console B's 1080p capture of the SAVE dialog
in its fourth zh-Hans run (2026-11-26): current time 12:23, "Last Saved" 12:21,
redacted to `^save_dialog\.`. `code-used-before-zh-hans-360p.png` is frame 109
of that run: the message after `CELEBRATE30TH`'s + that the code was used,
redacted to `^(mystery_gift|received_before)\.` of the `--gifts zh-Hans`
spec; `../../../assets/code-used-before-zh-Hans.png` is its first line, cut
from the unredacted frame at (275, 146, 90, 15) and scaled 3 times up.
