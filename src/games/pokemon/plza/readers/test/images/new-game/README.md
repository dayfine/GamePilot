# New game captures

The `language-list-*`, `look-picker-*`, `name-keyboard-*` and
`confirm-choices-*` frames are the fork's own AutoStoryNewGame/2026-11-15
captures (JPEG quality 80 at 1080p), kept whole: the game's own screens, the
only name typed is "1".

The `home-*` frames are console B's Switch HOME (2026-11-24 and -25), redacted
by `dev/reader_fixtures/redact_frame.py` to the one band the HOME title reader
probes (`plza.home_title`); the avatar, the clock and the game tiles are flat
mid-grey. Where the cursor is on PLZA's tile the band keeps its title; where it
is on another game, the band is a checkerboard of its own colours (`--pattern`),
so no other game's title is kept. With the spec from `write_probe_spec.exe
--intro` (run from `src/`):

    redact_frame.py SPEC '^plza\.home_title$' IN OUT
    redact_frame.py SPEC '^plza\.home_title$' --pattern 0,204,1920,76 IN OUT
