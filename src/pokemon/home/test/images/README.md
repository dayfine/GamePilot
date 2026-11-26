# Pokémon HOME captures, redacted

Console B's captures (2026-11-24/25), each redacted to what the readers probe
by `dev/reader_fixtures/redact_frame.py`, so no avatar, trainer name, stats, box
Pokémon or game library is kept: everything outside the kept probes' boxes is
flat mid-grey, and a box slot holding a Pokémon is mid-grey too (it still reads
as occupied). The cursor's probe box keeps a sliver of the Pokémon over it
(a Turtwig, on boxes-152-after-bank and boxes-saving). Each capture kept, with
the probe spec from `write_probe_spec.exe` (run from `src/`):

    redact_frame.py SPEC '^home\.(main_menu|banner)' main-menu.png
    redact_frame.py SPEC '^home\.banner' logging-in.png loading-blank-banner.png
    redact_frame.py SPEC '^home\.(game_list_page|game_frame|game_icon\.1\.1$)' game-select-cursor-on-bdsp.png
    redact_frame.py SPEC '^home\.(box\.|slot\.|cursor\.)' --grey-busy '^home\.slot\.' boxes-*.png (but boxes-saving)
    redact_frame.py SPEC '^home\.(box\.|slot\.|cursor\.|banner)' --grey-busy '^home\.slot\.' boxes-saving.png
    redact_frame.py SPEC '^home\.(app_title|app_tile0)' switch-home-cursor-on-pokemon-home.png
    redact_frame.py SPEC '^home\.(app_title|app_tile2)' switch-home-pokemon-home-third.png
    redact_frame.py SPEC '^home\.app_title' switch-home-cursor-on-za-home-fifth-cut.png

(each in place: IN and OUT the same file).
