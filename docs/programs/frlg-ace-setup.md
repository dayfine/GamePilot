# ACE Setup (FRLG)

Registry id `frlg.ace_setup`, group FRLG / Glitches (`src/program_registry`). Step 1 of the dex
collection build order (issue #15, roadmap `docs/roadmap/frlg-ace-balls.md`): it takes a save with
the Mail Glitch active (`frlg.mail_glitch` through 08-activate-and-verify) to the bootstrap of
pomeg-letterbombers' [FRLG non-JPN Post-E4 route](https://pomeg-letterbombers.github.io/pokemon-ace-notes/frlg-non-jpn-post-e4-route/):
species 0x0351 in Box 3 slot 1. It runs on mGBA; the Switch comes after the execution program.

| Checkpoint | Content |
|---|---|
| ace-01 | Celadon Dept. Store 1F to the Route 4 Pokémon Center: MIMIEN to the PC, a Magikarp bought from the salesman ($500) |
| ace-02 | Box 3 slot 1 checked empty, the ? Mail written `BULK UP / CAPABLE / KARATE CHOP / MAGIKARP`, the slot checked again |

## Why these steps

- **Magikarp seen.** The route's fourth word is MAGIKARP from the POKéMON group, which lists only
  the species seen. The save 08 leaves has seen Gyarados but not Magikarp; the Route 4 salesman
  is the cheapest way (no rod, no battle).
- **MIMIEN to the PC.** The ? Mail is what the editor opens on for a member whose mail index is
  0xFF while all six party mail records are taken. After 08 the records are the leaked record 0
  and the five filler mails, and MIMIEN's index is still 0 (that is how 08's duplication reads
  ABRA). With MIMIEN in the PC, the bought Magikarp (index 0xFF) takes slot 6. The ? Mail is
  the save's mail record 0xFF, which lies on Box 3 slot 1, so its first four words become that
  slot's personality (0x162E2753) and OT ID (0x2A812402), and the slot decrypts as species 0x0351.
- **Consequence for the duplication programs:** MIMIEN's stale index is gone once it is deposited.
  Item duplication still works through the ? Mail (pomeg's Mail Glitch notes: give mail to a
  member with no mail, confirm unchanged), but its editor then shows the ? Mail's words, not ABRA,
  so `duplicate_item`'s `word` would have to change.

## The pieces

- `Easy_chat_entry` (`src/games/frlg/actions`): writes words into the mail editor. Nothing is
  counted from the data (the grid lists only unlocked groups, POKéMON only the species seen): the
  cursor goes down a row at a time until its row shows the target, read against the group's
  look-alike words, and A goes in only with the cursor on it. Each field is read back.
- `Frlg_text.Easy_chat_words` and `src/games/frlg/assets/easy_chat_words_eng.txt` (made by
  `assets/extract/extract_frlg_easy_chat_words.py` from pret): every group and its word list in
  the game's order.
- `Frlg_readers.Easy_chat_screen`: the group grid's red rectangle and the word list's arrow.
- `Frlg_readers.Pc_box_screen` and `Ace_mail`'s `check_box_slot`: MOVE POKéMON, the hand to the
  slot, and PKMN DATA read. What is checked: the box by its default wallpaper (Box 3's Desert;
  the title is drawn white with a dark outline, which the templates do not read), an empty slot
  by a flat PKMN DATA panel and the hand's shadow on the first slot, an occupied one by text in
  the panel, its level (100) and its male mark. The species is not read: 0x0351 shows a ? picture
  and a garbled name. On mGBA the slot's RAM was checked by hand (personality, OT ID, species
  0x0351).

## Reader headroom

The colour readers' thresholds and their headroom on 14 mGBA frames, each under nine colour shifts,
are in `src/games/frlg/readers/test/test_ace_readers.ml`. The word arrow and the hand shadow are
the thin ones; both are confirmed by a second read (the row's words, the panel). Words and fields
are read with the text templates, every word read back on mGBA in each run. The Easy Chat scan
and the box slot's verdict are tested on fakes in `src/games/frlg/actions/test/test_ace_actions.ml`.

## Running

```sh
sh run/run_checkpoints_on_mgba.sh --program frlg.ace_setup --from ace-01 --to ace-02 --mode verification
```

The start state `ace-01.start.ss` is a copy of 08-activate-and-verify's end (Celadon Dept. Store 1F
(6, 2)). ace-02's start state, ace-01's end, is the backup from before the ? Mail is confirmed.

## For the execution program (step 2)

- The naming-screen typer and the box rename action: box names are the payload (Box 1-14 names),
  typed with the keyboard's three pages and read back.
- The trigger: PC, MOVE POKéMON, SELECT for Relocate mode (orange cursor), grab any Pokémon, swap
  with the 0x0351 in Box 3 slot 1, swap again. Box 13 slot 7 (the entrypoint) and every slot after
  it, and Boxes 14 on, must be empty; the test payload puts a shiny Lv 0 Bulbasaur in Box 9 slot
  30, which must be empty first.
- Codes depend on the game version: the ROM this was proven on reports FireRed (BPRE) 1.1.
- The box check here tells Box 3 by its wallpaper, and renamed boxes do not change wallpapers;
  a box title reader is still missing.
