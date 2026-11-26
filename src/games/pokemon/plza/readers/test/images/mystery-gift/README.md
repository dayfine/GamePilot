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

The SAVE dialog keeps its "Last Saved" date and time: the reader reads them.
