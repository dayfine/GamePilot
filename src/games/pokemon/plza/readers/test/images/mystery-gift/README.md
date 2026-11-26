# Mystery Gift captures, redacted

Console B's captures (2026-11-25; the synthetic-* ones are edited copies),
each redacted to what its own reader probes by
`dev/reader_fixtures/redact_frame.py`, so no party, box, summary or trainer
detail is kept: everything outside the kept probes' boxes is flat mid-grey.
The probe spec is `write_probe_spec.exe --gifts en` (run from `src/`); each in
place (IN and OUT the same file):

    redact_frame.py SPEC '^(boxes_screen|box_cell)\.' boxes-xerneas-in-box-1.png
    redact_frame.py SPEC '^mystery_gift\.(card_header|text_box)' card-vivillon.png
    redact_frame.py SPEC '^mystery_gift\.' claim-white-fade.png gift-list-*.png
    redact_frame.py SPEC '^save_dialog\.' *save-dialog*.png
    redact_frame.py SPEC '^main_menu' menu-*.png

The Japanese main menu (`menu-*`, read for its sixth row, Link Play, which
shows from the end of 03.15-mable-reward): `menu-six-rows-cursor-on-1` and
`-on-6` are console B's 1080p captures at that end (2026-11-25, party of six
and of five); `menu-six-rows-cursor-on-1-360p` and `-sliding-in-360p` are
frames 4 and 3 of the claim-gifts run of 2026-11-25 (640x360, the menu still
sliding in on frame 3: no sixth row yet); `menu-five-rows-*-360p` are frames
63 to 65 of 03.15-mable-reward's run of 2026-11-25, after Mable's talk and
before her reward (640x360). Each was redacted from its own capture, as above.

The SAVE dialog keeps its "Last Saved" date and time: the reader reads them.
