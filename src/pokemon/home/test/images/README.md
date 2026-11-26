# Pokémon HOME captures, redacted

Console B's captures (2026-11-24/25), each redacted by
`dev/reader_fixtures/redact_frame.py` to the boxes its readers probe; everything
else is flat mid-grey. The spec is `write_probe_spec.exe`'s (run from `src/`),
each command in place (IN and OUT the same file). What each capture keeps:

- main-menu: HOME's orange main-menu button with its title (寶可夢, "Pokémon")
  and the edges of the white row under it; the row's deposited count is grey
  (the reader counts the orange only). The bottom banner strip, empty.

      redact_frame.py SPEC '^home\.(main_menu|banner)' --grey 1180,326,330,46 main-menu.png

- logging-in, loading-blank-banner: the bottom banner strip and its two text
  lines (HOME's own messages; the blank one empty).

      redact_frame.py SPEC '^home\.banner' IN IN

- game-select-cursor-on-bdsp: the game list's tile frame edges (the cursor's
  on BDSP's tile) and one whole tile, PLZA's icon beside it: it shows that the
  console holds Legends: Z-A.

      redact_frame.py SPEC '^home\.(game_list_page|game_frame|game_icon\.1\.1$)' IN IN

- boxes-152-before-bank-cursor-0-0, boxes-152-after-bank, boxes-158-left-paged,
  boxes-159-left-paged, boxes-164-left-paged, boxes-167-left-paged, and
  boxes-saving: the box counter ("152/300" and so on), each slot's box (an
  empty slot as it is; a slot holding a Pokémon a checkerboard in the slot's
  own mean colour, which a reader still reads as occupied but which shows no
  Pokémon), and in each cursor box only the cursor's green arrow (the pixels
  its probe counts; no sliver of the Pokémon behind it). boxes-saving keeps
  its two "saving, do not close HOME" lines too.

      redact_frame.py SPEC '^home\.(box\.|slot\.|cursor\.)' --pattern-busy '^home\.slot\.' --line-test '^home\.cursor\.' IN IN
      (boxes-saving: '^home\.(box\.|slot\.|cursor\.|banner)', the same options)

- switch-home-cursor-on-pokemon-home, switch-home-pokemon-home-third,
  switch-home-cursor-on-za-home-fifth-cut: the Switch's HOME title row (the
  selected game's name: Pokémon HOME, Brilliant Diamond and Legends: Z-A, so
  which games the console holds) and HOME's tile where the reader finds it
  (none on the cut one). No profile icon, clock or other tile.

      redact_frame.py SPEC '^home\.(app_title|app_tile0)' switch-home-cursor-on-pokemon-home.png
      redact_frame.py SPEC '^home\.(app_title|app_tile2)' switch-home-pokemon-home-third.png
      redact_frame.py SPEC '^home\.app_title' switch-home-cursor-on-za-home-fifth-cut.png
