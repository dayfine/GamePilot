# ACE

The second half of arbitrary code execution (ACE) in FireRed, after [ACE Setup](frlg.ace_setup.md):
it types a short program as the names of the 14 PC boxes, then makes the game run them by swapping
the glitch Pokémon 0x0351 in the PC. The program is Sleipnir17's "Get any item" code: it puts 999
of one item in the PC's item storage. Each run makes one item; run it again for another.

**What you get.** 999 of the chosen item in the PC (Master Balls or Luxury Balls today), of which
`withdraw` go to the bag, and the box names left holding that item's code. The game is saved twice:
once with the code typed (the "code save"), and again once the items are in the bag.

<!-- generated:backends -->
Runs on: mGBA.
<!-- /generated -->

## Before you start

What the save needs:

- [ACE Setup](frlg.ace_setup.md) done: species 0x0351 (a male Lv 100 Pokémon with a ? picture) in
  Box 3 slot 1, standing below the Route 4 Pokémon Center's PC, facing it.
- A Pokémon in Box 1 (MIMIEN on the Mail Glitch save), or already in Box 3 slot 2: the swap
  partner. The first Pokémon in Box 1 is used, whichever slot it is in.
- Box 13 from slot 7 on and all of Box 14 empty. The program checks this before it types anything.
- Fewer than 30 kinds of item in the PC's item storage, and room in the bag: what it holds of the
  item plus `withdraw` at most 999.
- English FireRed 1.1. The code's exit jumps to an address in that ROM; other versions and the
  Switch release are not checked yet.

What the pre-flight checks (generated from the plan):

<!-- generated:needs -->
- at the start, Route4_PokemonCenter_1F
<!-- /generated -->

## Running it

Every run names the item and how many to withdraw.

<!-- generated:options -->
Give each as `--options KEY=VALUE`:

| Key | Values | When not given | What it chooses |
|---|---|---|---|
| `item` | master-ball \| luxury-ball | required | the item the code makes, 999 of it in the PC's item storage |
| `withdraw` | 1 to 999 | required | how many of them go from the PC to the bag |
<!-- /generated -->

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh frlg.ace --from 01-enter-code --to 02-trigger --mode verification
```
<!-- /generated -->

Add the options to the command, for example `--options item=master-ball --options withdraw=50`.
On mGBA the start state is `01-enter-code.start.ss` in `GAMEPILOT_STATES`: the state ACE Setup's
02-write-ace-mail ends in. `02-trigger.start.ss` is 01's end, the code save.

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01-enter-code | The item's code typed as the 14 box names, then saved: the code save |
| 02-trigger | The code run by the double swap: the item x999 in the PC, the asked count in the bag, saved |

<!-- plans: 42586305bffa -->
<!-- /generated -->

In plain words:

1. Opens the PC's MOVE POKéMON, checks Box 3 slot 1 shows 0x0351, and checks the Box 13 and 14
   slots are empty. Then it goes through the boxes from Box 1 and renames each to the item's code,
   reading each name back from the box title. A box already named right is skipped, so a second
   item retypes only Boxes 5-8. Then it saves: the code save.
2. Checks the item storage and the bag have room. In MOVE POKéMON it moves the first Pokémon in
   Box 1 next to 0x0351 (Box 3 slot 2), picks 0x0351 up and swaps it with that Pokémon twice:
   the second swap runs the box names. It checks the box screen still answers, opens ITEM STORAGE
   to find the item x999, withdraws `withdraw` of it, checks the bag's count went up by that much,
   and saves.

## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| 01-enter-code | at the start, Route4_PokemonCenter_1F |
| 02-trigger | at the start, Route4_PokemonCenter_1F |
<!-- /generated -->

Any failure in 02-trigger goes back to the code save without saving (on mGBA the run's start
state is loaded), and the run stops: nothing retries the code on its own. Typing in 01 changes
nothing the game runs until 02, so 01 retries.

## Known limits

- Two items so far: Master Ball and Luxury Ball. Another item joins `ace_presets.json` (and the
  program's `item` choices) once its code is checked on mGBA; Rare Candy, Repel and Escape Rope
  are (docs/design/FRLG-ACE-Execution.md).
- The bag's pocket is not checked for a free slot: the Poké Balls pocket holds every kind of ball.
- mGBA only. The Switch release's ROM differs, and the code's exit has not been tried there.
- A second run for an item already in the item storage adds a second stack of it.

## How it works

The box names are read as ARM code when 0x0351's name, too long for its buffer, overwrites the
box screen's swap callback with an address in Box 13: the CPU slides through empty Box 13 and 14
slots into the names. The design note, docs/design/FRLG-ACE-Execution.md, has the mechanism, the
code box by box and what was verified on mGBA.

The names are data
(`src/games/frlg/assets/ace_presets.json`); a unit test (`test_ace_presets`) encodes them with the
game's character table and runs the ARM words, checking the code stores 999 and the item's id.
The actions are `Ace_code` (the checks and the typing, on `Box_rename`'s naming), `Ace_trigger`
(the swaps) and `Ace_item` (room, x999, withdraw), in `src/games/frlg/actions/`.
