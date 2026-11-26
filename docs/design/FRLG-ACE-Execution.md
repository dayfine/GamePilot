# FRLG ACE execution (`frlg.ace`), design (draft, 2026-11-25)

Steps 3 and 4 of [A3](../roadmap/frlg-ace-balls.md): the program that types a payload as PC box
names and triggers it through species 0x0351, which `frlg.ace_setup` leaves in Box 3 slot 1. This
note settles the payload for the first preset, "bag prep", says what of it is proven on mGBA, and
lays out the program: presets as data, checkpoints, guardrails, the trigger and the readers still
missing. The naming-screen typer and the box rename action (steps 1 and 2) are built separately;
this note only states what it needs from them.

Scope: English FireRed 1.1 (BPRE rev 1), on mGBA. The Switch release and other versions are
open questions at the end.

## How the code runs

From pomeg-letterbombers' [Post-E4 route](https://pomeg-letterbombers.github.io/pokemon-ace-notes/frlg-non-jpn-post-e4-route/),
its [Grab ACE Exit](https://pomeg-letterbombers.github.io/pokemon-ace-notes/frlg-grab-ace-exit/)
page and its [FRLG FAQ](https://pomeg-letterbombers.github.io/pokemon-ace-notes/frlg-faq/), checked
on mGBA against pret's pokefirered (symbols for rev 1) with breakpoints:

- Swapping two Pokémon in MOVE POKéMON's Relocate mode runs `Task_ShiftMon`, which calls
  `gStorage->monPlaceChangeFunc` every frame until it returns false.
- When the swap picks 0x0351 up, the PKMN DATA panel copies its species name. 0x0351 indexes past
  `gSpeciesNames`, so the name runs on for 157 bytes, past `displayMonTexts`, and overwrites
  `monPlaceChangeFunc` with `0x02070602` (seen on mGBA at frame 16 of the second swap; the first
  swap still calls `MonPlaceChange_Shift`).
- `0x02070602` is a mirror of EWRAM `0x02030602`: Box 13 slot 8 (the save blocks shift by a small
  random offset at each load; the slot moves with them). The call enters ARM mode with the PC 2 off
  word alignment, which mGBA keeps (breakpoints hit at `...602`, `...666`). The empty slots of Box
  13 and 14 are zero words, `andeq r0, r0, r0`, so execution slides into the box names, which
  follow Box 14 in `PokemonStorage`.
- The box names are 14 x 9 bytes (8 characters and the end mark `0xFF`), executed as ARM words that
  straddle the names. The payload computes the address it writes from the PC, so it works wherever
  the save blocks sit.
- It returns by clearing `r0` (false) and jumping to a `BX LR`. Pomeg's standard exit (`movs pc,
  #0x354`) jumps into the GBA BIOS. **mGBA without a BIOS file runs its own HLE BIOS, and that
  exit resets the game** (tried: the title screen came up, nothing written). The FAQ's
  "Switch-adjusted" exit (`bic r0, #0xFF; mvn r12, #0x08000003; rsc pc, r12, #0x398`) jumps instead
  to `0x08000398` in the ROM, which is `BX LR` in 1.1 (read from the ROM): it needs no BIOS and is
  the one used here.

## The payload: "Get any item"

Sleipnir17's "Get any item" code, from his
[list of FRLG grab-ACE box-name codes](https://pastebin.com/VAgKwjwJ) (linked from the pomeg notes'
home page), "for all non-Japanese versions". It writes one item into **slot 30 of the PC's item
storage** with quantity 999 (or 65535); the game moves it up to the first free slot the next time
the item storage opens. The code (r12 = slot 30's address - 0xC4, from the PC):

| Box | Name (as Sleipnir writes it) | What it does |
|---|---|---|
| 1 | `xFUnDRRn` | `sbc r12, pc, #0xEC`; `sbc r12, r12, #0xBE00`: r12 from the PC (`x`, not `z`: the variant for accurate emulators and consoles) |
| 2 | `……o/E!n ` | `movs r11, #0xFF`; `adc r11, r11, #0x2E8`: r11 = 999 |
| 3 | `EE …l‘  ` | filler; `mvnlt r11, #0`: skipped, so r11 stays 999 (`o` in place of `‘` makes it `mvn`: 65535) |
| 4 | `E♀BRm   ` | `strh r11, [r12, #0xC6]`: the quantity |
| 5 | `?……o    ` | `movs r11, #0xC?`: the item's last hex digit |
| 6 | `EEE?D!n ` | `adc r11, r11, #0xC?0`: third digit |
| 7 | `EE?B!n  ` | `adc r11, r11, #0xC?00`: second digit |
| 8 | `E?/!n   ` | `adc r11, r11, #0xC?000`: first digit; the low halfword is the item |
| 9 | `’BRm    ` | `strh r11, [r12, #0xC4]`: the item |
| 10 | ` FoHIoor` | exit: `bic r0, #0xFF`; `mvn r12, ...` |
| 11 | `xn` | exit: `rsc pc, r12, #0x398` (to `BX LR` at `0x08000398`) |
| 12-14 | `A` | not reached; named `A` so every box has a known name |

`‘` is the left single quote, `’` the right one (the keyboard's `'`); `…` is one character.
Sleipnir writes the names with trailing spaces to 8 characters, but they are not needed: typed
without them (Box 4 `E♀BRm`, Box 8 `EI/!n`, and so on), the code still works (see "Verified on
mGBA"). The program types them without trailing spaces. Box 3's inner space (`EE …l‘`) stays.
Boxes 1-4 and 9-11 are the same for every item; Boxes 5-8 carry the item's id (Sleipnir's digit
tables).

**Bag prep**, the boxes that change (Boxes 5-8):

| Item | Id | Box 5 | Box 6 | Box 7 | Box 8 |
|---|---|---|---|---|---|
| Master Ball | 0x0001 | `G……o    ` | `EEEJD!n ` | `EEIB!n  ` | `EI/!n   ` |
| Luxury Ball | 0x000B | `Q……o    ` | `EEEJD!n ` | `EEIB!n  ` | `EI/!n   ` |
| Rare Candy | 0x0044 | `J……o    ` | `EEEND!n ` | `EEIB!n  ` | `EI/!n   ` |
| Repel | 0x0056 | `L……o    ` | `EEEOD!n ` | `EEIB!n  ` | `EI/!n   ` |
| Escape Rope | 0x0055 | `K……o    ` | `EEEOD!n ` | `EEIB!n  ` | `EI/!n   ` |

Every character is on the naming screen's keyboard (pret `naming_screen.c`: letters on the upper
and lower pages, space on both; `…`, `‘`, `'`, `♀`, `/`, `!` on the symbols page).

**What a confirmed box name leaves in memory** (pret pokefirered at `ce6406d`):

- The box's naming screen gets `gPokemonStoragePtr->boxNames[box]` as its destination
  (`pokemon_storage_system.c` 118-121 `GetBoxNamePtr`; `pokemon_storage_system_tasks.c` 2075
  `DoNamingScreen(NAMING_SCREEN_BOX, GetBoxNamePtr(StorageGetCurrentBox()), ...)`).
- The entry buffer starts as all `EOS` (`naming_screen.c` 494 `memset(sNamingScreen->textBuffer,
  EOS, ...)`); the box template does not copy the old name in (2096 `.copyExistingString = FALSE`,
  2097 `.maxChars = BOX_NAME_LENGTH`). Typing fills it from the front (1845-1849 `BufferCharacter`);
  backspace writes `EOS` back (1817).
- On confirm, `SaveInputText` (1851-1864) copies `maxChars + 1` = 9 bytes with `StringCopyN`, a plain
  byte copy that does not stop at `EOS` (`string_util.c` 112-120). It copies only if some character
  is not a space or `EOS` (1856-1858): a name of only spaces leaves the old name as it was.

So the bytes after the end mark are **`0xFF`, the whole 9-byte name rewritten**; nothing of the
old name is left over.

Money and coins, also in the fork plan's preset, are not in Sleipnir's list. Money is stored XORed
with the save's key, so it needs a new code (E-Sh4rk's
[CodeGenerator](https://e-sh4rk.github.io/CodeGenerator/) writes box-name code). Left out of the
first preset.

## Verified on mGBA

On a copy of `02-write-ace-mail.end.ss` (0x0351 in Box 3 slot 1, MIMIEN in Box 1 slot 1), the box
names written into memory instead of typed, the trigger pressed through the menus by a script, the
results read from memory:

- PC item slot 30 after each run: Master Ball (1) x999, Luxury Ball (11) x999, Rare Candy (68)
  x999, Repel (86) x999, Escape Rope (85) x999, plus Full Heal (19) x999, item 0x1CC x999, and
  Luxury Ball x65535 with the `o` variant. Seven runs in a row in one PC session, holding 0x0351 and
  swapping it twice with MIMIEN each time; the game kept running.
- The bag: ITEM STORAGE showed MASTER BALL x999; WITHDRAW of 999 said "There is no more room in the
  BAG." (the save held one Master Ball already); 998 went in. The Poké Balls pocket then read
  Master Ball x999 (quantity XORed with the save key), the PC kept one.
- The standard BIOS exit (`     …oa` / `…o`) reset the game on mGBA's HLE BIOS.
- Short names (2026-11-25, Master Ball): every name with trailing spaces written without them
  (Boxes 2-9), Boxes 12-14 named `A`, three ways: the end mark then `0xFF` fill (what the naming
  screen leaves), the end mark then the long version's old bytes, and the long version itself. All
  three gave MASTER BALL x999 in slot 30, and the box screen still answered after the swaps. The
  bytes the spaces held land in filler words: they become `0xFFFFFFFF` (condition NV, never run) or
  `BFBFFFFF`-like `svclt` words, skipped because the LT condition is false at that point, the same
  condition the 999 variant's `mvnlt` already relies on.
- Partner in Box 3: with MIMIEN in Box 3 slot 2 (put there in memory, not through the PC), the
  trigger was SELECT, A on 0x0351, RIGHT, A, A, all in Box 3: MASTER BALL x999, game still running.

Not verified: typing the names (the typer is not built), saving and loading after a run, the 1.0
ROM, other languages, the Switch. Pomeg's own check code (a Bulbasaur in Box 9 slot 30) did not
appear in one memory-written run; not chased, since the item code is what the program runs.

## The program

`frlg.ace`, registered in `program_registry` with backends mGBA (Switch later), plans in
`src/games/pokemon/frlg/programs/ace/plans/`.

Decided in the user's review of this note (2026-11-25):

- **First version**: Master Balls (about 50) and Luxury Balls (about 300). Each run makes 999 in the
  PC's item storage and withdraws only what was asked; the rest stays in the PC.
- **One template checkpoint pair**, run once per item, driven by program options
  `--options item=<slug> --options withdraw=<n>` (declared on its registry descriptor:
  `item` one of the vetted slugs, `withdraw` 1 to 999). The item must be in a vetted table; an item not in it is refused
  before anything is pressed.
- **Unused boxes** (12-14) are named `A`.
- **Names are typed without trailing spaces**; the Switch warning about spaces in Boxes 4, 8 and 12
  is moot unless a test shows spaces are needed (the mGBA test above shows they are not).

### Codes and the vetted table, as data

`src/games/pokemon/frlg/assets/ace_presets.json`: the literal box names, so what is typed is what was
reviewed.

```json
{
  "format": "gamepilot-ace-presets/1",
  "codes": {
    "get_item_999": {
      "source": "https://pastebin.com/VAgKwjwJ (Get any item), exit: pomeg FRLG FAQ",
      "games": ["firered-en-1.1"],
      "boxes": {"1": "xFUnDRRn", "2": "……o/E!n", "3": "EE …l‘", "4": "E♀BRm",
                "9": "’BRm", "10": " FoHIoor", "11": "xn", "12": "A", "13": "A", "14": "A"},
      "item_boxes": [5, 6, 7, 8]
    }
  },
  "items": {
    "master-ball": {"code": "get_item_999", "id": 1,
                    "boxes": {"5": "G……o", "6": "EEEJD!n", "7": "EEIB!n", "8": "EI/!n"}},
    "luxury-ball": {"code": "get_item_999", "id": 11,
                    "boxes": {"5": "Q……o", "6": "EEEJD!n", "7": "EEIB!n", "8": "EI/!n"}}
  }
}
```

Rare Candy, Repel and Escape Rope (table above) are proven on mGBA too and join the table
when wanted. A unit test decodes every name through the game's character table, rebuilds the 14 x 9
bytes as the naming screen leaves them (`0xFF` after the end mark), and checks the ARM words: the
quantity 999 stored at `+0xC6`, the entry's `id` at `+0xC4`, the exit words. A typo in the data
fails the test, not the run.

### Checkpoints

The pair, run for one item at a time
(`gamepilot run frlg.ace --options item=luxury-ball --options withdraw=300`):

**01-enter-code.** Starts saved in the overworld facing a Pokémon Center PC.

1. Refuse an item not in the table, or `withdraw` outside 1-999.
2. Before typing, read the boxes: Box 13 slot 7 onward and all of Box 14 empty (pomeg; Sleipnir
   asks for Boxes 13 and 14 empty), and 0x0351 in Box 3 slot 1 (level 100, male, the ? icon: the
   readers of `Ace_mail.check_box_slot`).
3. Rename all 14 boxes to the code's names, skipping a box whose current name already reads right;
   a name the reader cannot read is retyped. Each typed name is read back. On a second item only
   Boxes 5-8 differ, so only they are typed.
4. Save. This save, "the code save", is what a failed trigger goes back to.

**02-trigger.** Starts at the code save.

1. Before the PC: the item storage holds fewer than 30 items (slot 30 is where the code writes),
   and the bag has room: what it holds plus `withdraw` is at most 999, and the pocket has a free
   slot if the item is not in it yet.
2. Partner: MIMIEN, moved once from Box 1 slot 1 to Box 3 slot 2 (skipped when Box 3 slot 2
   already holds it), so the swap needs no box scrolling.
3. MOVE POKéMON (the box opens on Box 3, hand on slot 1), SELECT (hand orange), A (holds 0x0351),
   RIGHT, A (swap), A (swap back: the code runs here), LEFT, A (0x0351 back in slot 1; this last
   put-down is not yet tried on mGBA).
4. Check the game is alive: the box screen still reads and answers a move. Leave the PC.
5. PLAYER's PC, ITEM STORAGE, WITHDRAW ITEM: the item's row reads x999. Withdraw `withdraw`.
6. Check the bag count rose by `withdraw` (`Bag_items.count`), then save.

Any failure after the code save soft-resets (`Soft_reset`) back to it, unsaved, and stops.

Notes: pomeg's FAQ says to leave the PC soon after viewing 0x0351 and keep it out of Boxes 13 and
14; its long name also corrupts Box 13 slots 7-9 now and then, which the next run's step 2 catches.
A second run for an item already in item storage adds a second stack of it there.

### Guardrails (from the roadmap)

- Save in the overworld before the PC: 01's start, and the code save before the trigger.
- Check every character and the length of each name before any press: the table's test, and
  again at run time against the keyboard's character set.
- Type and confirm each name with cursor and screen checked, then read the name back: the typer and
  the box title reader.
- After the trigger, check the game still answers and the expected change happened (ITEM STORAGE
  lists the item x999) before saving.
- On a mismatch, soft reset to the code save and stop.
- The code may be called more than once in one swap (breakpoints hit the entry several times):
  every payload must give the same result if run twice. "Get any item" does: it writes the same
  slot.

### Readers needed

| Reader | For | Exists? |
|---|---|---|
| Box title (the name on the box screen) | skip boxes already right; read each name back | no (`Pc_box` tells Box 3 by its wallpaper) |
| Box slots empty (Box 13 slot 7+, Box 14) | 01's check before typing | partly (the hand and PKMN DATA, slot by slot) |
| Hand colour (normal or orange) | Relocate mode on before A | no |
| PKMN DATA of 0x0351 and of MIMIEN | what is held, what is in slot 2 | yes (level, male mark; species names) |
| PC menu with PLAYER's PC, ITEM STORAGE menu | reaching WITHDRAW ITEM | partly (`Pc_screen` reads the PC list) |
| Item storage list: names, x counts, how many rows | fewer than 30; the item arrived | no |
| Quantity box (`xNNN`) | withdraw the right count | no |
| Bag counts | room before, the count after | yes (`Bag_items.count`) |

## Open questions

1. Money and coins: write a new code (unverified) or leave them out?
2. The Switch: the exit jumps to a ROM address (`0x08000398`), and the rerelease's ROM is modified;
   check it there before the first console run, after mGBA runs the whole program.
