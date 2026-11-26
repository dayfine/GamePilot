# Switch HOME captures, redacted

Console B's HOME menu and user select (2026-11), redacted by
`dev/reader_fixtures/redact_frame.py` to Home_screen's probe boxes (the spec
from `write_probe_spec.exe`, its nso-gba boxes mapped into the frame), so no
profile icon, clock or game beyond the four probed tiles is kept: the top bar,
the icon row, the bottom row, the game tiles and the cursor strips stay, the
rest is mid-grey. Each in place:

    redact_frame.py SPEC '^(home\.(top|iconrow|bottom|game_slot|close_game|cursor|tile)|user\.|close_game\.)' IN IN

home-dimmed adds `--fill-mean` (its own mean colour, so it stays dark for
Home_screen.black) and `--pattern 184,582,84,84` (the profile's icon on
FireRed's "Playing" badge); home-close-software-popup adds the same pattern
and `--pattern 558,556,84,86` (the icon on the dialog's FireRed art);
user-select adds `--pattern 852,634,214,284`, the profile's
icon and name made a checkerboard (the user slot keeps its detail).
In delete-save/, user-select-native (with the same pattern),
za-page-delete-save-data-for-user (the profile's name and icon) and
game-list-za-first (the library) are redacted to the delete-save spec's boxes
(`write_probe_spec.exe delete-save`, '^delete_save\.'). The other captures
(black, the Game Freak intro, System Settings' menus and dialogs) show no
profile and are whole; FireRed's load menu shows the save's in-game name.

Only whole-picture probes (home.picture, start_game.black), the boxes over
the profile, and the code keyboard's probes on home-cursor-on-last-played and
user-select (fixtures/code_keyboard.probes.jsonl: their wide box now reads
mostly fill) read differently from the unredacted captures; every reader reads
them as before (no keyboard on either).
