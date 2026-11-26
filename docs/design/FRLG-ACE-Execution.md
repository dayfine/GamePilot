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

| Box | Name | What it does |
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
| 12-14 | anything | not reached |

`‘` is the left single quote, `’` the right one (the keyboard's `'`); `…` is one character.
Spaces are part of the names: every name but Box 11's is exactly 8 characters. Boxes 1-4 and 9-11
are the same for every item; Boxes 5-8 carry the item's id (Sleipnir's digit tables).

**Bag prep**, the boxes that change (Boxes 5-8):

| Item | Id | Box 5 | Box 6 | Box 7 | Box 8 |
|---|---|---|---|---|---|
| Master Ball | 0x0001 | `G……o    ` | `EEEJD!n ` | `EEIB!n  ` | `EI/!n   ` |
| Luxury Ball | 0x000B | `Q……o    ` | `EEEJD!n ` | `EEIB!n  ` | `EI/!n   ` |
| Rare Candy | 0x0044 | `J……o    ` | `EEEND!n ` | `EEIB!n  ` | `EI/!n   ` |
| Max Repel | 0x0056 | `L……o    ` | `EEEOD!n ` | `EEIB!n  ` | `EI/!n   ` |
| Escape Rope | 0x0055 | `K……o    ` | `EEEOD!n ` | `EEIB!n  ` | `EI/!n   ` |

Every character is on the naming screen's keyboard (pret `naming_screen.c`: letters on the upper
and lower pages, space on both; `…`, `‘`, `'`, `♀`, `/`, `!` on the symbols page). The naming screen
saves all 9 bytes, padded with `0xFF` (`SaveInputText`), and ignores a name of only spaces.

Money and coins, also in the fork plan's preset, are not in Sleipnir's list. Money is stored XORed
with the save's key, so it needs a new code (E-Sh4rk's
[CodeGenerator](https://e-sh4rk.github.io/CodeGenerator/) writes box-name code). Left out of the
first preset.

## Verified on mGBA

On a copy of `02-write-ace-mail.end.ss` (0x0351 in Box 3 slot 1, MIMIEN in Box 1 slot 1), the box
names written into memory instead of typed, the trigger pressed through the menus by a script, the
results read from memory:

- PC item slot 30 after each run: Master Ball (1) x999, Luxury Ball (11) x999, Rare Candy (68)
  x999, Max Repel (86) x999, Escape Rope (85) x999, plus Full Heal (19) x999, item 0x1CC x999, and
  Luxury Ball x65535 with the `o` variant. Seven runs in a row in one PC session, holding 0x0351 and
  swapping it twice with MIMIEN each time; the game kept running.
- The bag: ITEM STORAGE showed MASTER BALL x999; WITHDRAW of 999 said "There is no more room in the
  BAG." (the save held one Master Ball already); 998 went in. The Poké Balls pocket then read
  Master Ball x999 (quantity XORed with the save key), the PC kept one.
- The standard BIOS exit (`     …oa` / `…o`) reset the game on mGBA's HLE BIOS.

Not verified: typing the names (the typer is not built), saving and loading after a run, the 1.0
ROM, other languages, the Switch. Pomeg's own check code (a Bulbasaur in Box 9 slot 30) did not
appear in one memory-written run; not chased, since the item code is what the program runs.

## The program

`frlg.ace`, registered in `program_registry` with backends mGBA (Switch later), plans in
`src/games/frlg/programs/ace/plans/`.

### Presets as data

`src/games/frlg/assets/ace_presets.json`: the literal box names, so what is typed is what was
reviewed.

```json
{
  "format": "gamepilot-ace-presets/1",
  "codes": {
    "get_item_999": {
      "source": "https://pastebin.com/VAgKwjwJ (Get any item), exit: pomeg FRLG FAQ",
      "games": ["firered-en-1.1"],
      "boxes": {"1": "xFUnDRRn", "2": "……o/E!n ", "3": "EE …l‘  ", "4": "E♀BRm   ",
                "9": "’BRm    ", "10": " FoHIoor", "11": "xn"},
      "item_boxes": [5, 6, 7, 8]
    }
  },
  "presets": {
    "bag-prep": [
      {"code": "get_item_999", "item": "master-ball", "id": 1,
       "boxes": {"5": "G……o    ", "6": "EEEJD!n ", "7": "EEIB!n  ", "8": "EI/!n   "}},
      {"code": "get_item_999", "item": "luxury-ball", "id": 11, "boxes": {"5": "Q……o    ", "...": "..."}}
    ]
  }
}
```

A unit test decodes every name through the game's character table, rebuilds the ARM words and
checks what they store: quantity 999 at `+0xC6`, the entry's `id` at `+0xC4`, the exit words. A
typo in the data fails the test, not the run.

### Checkpoints

One checkpoint per item (proposed; the roadmap says one per preset): `01-master-balls`,
`02-luxury-balls`, `03-rare-candies`, `04-max-repels`, `05-escape-ropes`. Each starts saved in the
overworld below a Pokémon Center PC and ends there, saved, with the stack in the bag. One checkpoint
per item keeps a retry to one execution and one save. Each:

1. Pre-flight: 0x0351 in a box outside Boxes 13 and 14 (level 100, male, the ? icon: the readers of
   `Ace_mail.check_box_slot`); Box 13 slot 7 onward and Box 14 empty (pomeg; Sleipnir asks for
   Boxes 13 and 14 empty); another Pokémon to swap with; the bag holds less than 999 of the item
   and has a free slot in its pocket; the PC item storage has fewer than 30 items.
2. Rename the boxes whose names differ from the preset (the box rename action, reading each name
   back). The first item types Boxes 1-11; later ones only Boxes 5-8.
3. Trigger (below).
4. PLAYER's PC, ITEM STORAGE, WITHDRAW ITEM: the item's row shows x999; withdraw 999 minus what the
   bag holds.
5. Check the bag count (`Bag_items.count`), then save.

### Trigger action

Pressed and checked on mGBA:

1. Facing the PC: A through "booted up the PC", BILL's PC, "Accessed BILL's PC", "POKéMON Storage
   System opened", then MOVE POKéMON. The box opens on the current box with the hand on slot 1.
2. With the hand on 0x0351: SELECT (the hand turns orange: Relocate mode), A (picks it up).
3. Move to the swap partner. On the setup save that is MIMIEN in Box 1 slot 1: UP to the box title,
   LEFT twice (wait for each box to scroll in), DOWN, LEFT to slot 1. Input during the scroll is
   lost, so each move waits for the screen to settle (a reader, not a count).
4. A (swap), A (swap back). The code runs during the second swap.
5. Put 0x0351 down in an empty slot (Box 1 slot 2), B, "Continue BOX operations?" NO.

Pomeg's FAQ: leave the PC soon after viewing 0x0351 and keep it out of Boxes 13 and 14; its long
name also corrupts Box 13 slots 7-9 now and then.

### Guardrails (from the roadmap)

- Save in the overworld before the PC: the checkpoint's start.
- Check every character and the length of each name before any press: the preset test, and again
  at run time against the keyboard's character set.
- Type and confirm each name with cursor and screen checked, then read the name back: the typer and
  the box title reader.
- After the trigger, check the game still answers (the box screen still reads after the swaps) and
  the expected change happened (ITEM STORAGE lists the item x999) before saving.
- On a mismatch, stop without saving. On mGBA the start state is the backup; on the Switch, the
  last save is.
- The code may be called more than once in one swap (breakpoints hit the entry several times):
  every payload must give the same result if run twice. "Get any item" does: it writes the same
  slot.

### Readers needed

| Reader | For | Exists? |
|---|---|---|
| Box title (the name on the box screen) | read each name back after renaming; tell boxes apart | no (`Pc_box` tells Box 3 by its wallpaper) |
| Hand colour (normal or orange) | Relocate mode on before A | no |
| Hand position over a slot, and box scrolled in | moving to the swap partner | partly (`Ace_mail.check_box_slot`, `Pc_box`) |
| PKMN DATA of 0x0351 | which Pokémon is held | yes (level, male mark) |
| PC menu with PLAYER's PC, ITEM STORAGE menu | reaching WITHDRAW ITEM | partly (`Pc_screen` reads the PC list) |
| Item storage list: names and x counts | the item arrived; how many | no |
| Quantity box (`xNNN`) | withdraw the right count | no |
| Bag counts | the end check | yes (`Bag_items.count`) |

## Open questions

1. One checkpoint per item (proposed) or one per preset (roadmap)?
2. Money and coins: write a new code (unverified) or drop them from bag prep?
3. The Switch: the FAQ says the rerelease's emulator mishandles spaces typed into the last three
   characters of Boxes 4, 8 and 12 (leave them out and confirm early), and Box 4 (`E♀BRm   `) and
   Box 8 (`EI/!n   `) end in three spaces; the exit's ROM target needs checking there. Verify on
   the console only after mGBA runs the whole program.
4. The swap partner: MIMIEN in Box 1 is what `frlg.ace_setup` leaves. Should the program instead
   put 0x0351 beside another Pokémon in its own box, so no box has to scroll?
5. Quantities: 999 of each (one full stack). A4 asks for 50 Luxury Balls per legendary, so 999 covers
   it; enough?
