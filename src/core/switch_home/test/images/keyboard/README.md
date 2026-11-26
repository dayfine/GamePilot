# Code keyboard captures, redacted

Console B's keyboards (a name keyboard in German and Japanese, PLZA's code
keyboard), each redacted to Code_keyboard's probes by
`dev/reader_fixtures/redact_frame.py`, so no typed name or title is kept: the
keys and the cursor's box stay, everything else is flat mid-grey. In place,
the spec from `write_probe_spec.exe code-keyboard` (run from `src/`):

    redact_frame.py SPEC '^code_keyboard\.' IN IN

The fixtures read the same as from the unredacted captures.
