# A3. ACE: Master Balls and Luxury Balls

Goal: use arbitrary code execution, bootstrapped from the Mail Glitch, to put large stacks of Master
Balls and Luxury Balls (and other prep items) in the bag, so A4 and A6 never run short of balls.

## Source plan

The fork's `docs/design/FRLG-DexCollection-Plan.md` (fork PR #776, Track 1B "Generic Box-Name ACE
Runner") is the plan to carry over:

- A runner with **named presets** and **custom Box 1-14 names**: the payload is typed as PC box names
  with the naming-screen keyboard, then triggered.
- First preset, "bag prep": Master Balls in Balls slot 1, Luxury Balls in slot 2, Rare Candies, Max
  Repels, Escape Ropes, coins and money.
- **Guardrails:** save in the overworld before the PC; check every character and the length of each
  box name before any press; type and confirm each name with the cursor and screen checked; trigger;
  check the game still answers and the expected change happened before saving again; on a mismatch,
  stop without saving.
- The exact payloads for the Switch release must be verified against its memory layout before any
  preset ships (the plan says so). The mGBA payloads are in `docs/design/FRLG-ACE-Execution.md`.

Track 1A of the same plan (Mail Glitch Activation) is what GamePilot already ported as 01-celadon-setup..08-activate-and-verify.
How the Mail Glitch leads to ACE is in the
[pomeg-letterbombers ACE notes](https://pomeg-letterbombers.github.io/pokemon-ace-notes/mail-glitch).

## Steps

1. **Naming-screen typer** (`src/games/pokemon/frlg/actions`): all three pages (upper, lower, symbols), the
   key grids taken from `naming_screen.c` in the pret decomp, cursor and page reader to check each
   move. Needed for the full ACE character set; it also covers player and nickname typing.
2. **Box rename action**: PC, Box options, rename, type, confirm, read the new name back.
3. **ACE runner** (`frlg.ace`): presets as data (`src/games/pokemon/frlg/assets/ace_presets.json`), the
   guardrails above as checks in the plan, one checkpoint per preset.
4. **Proof on mGBA**: one preset end to end, with a bag reader check of each item count.

## Prerequisites

- 08-activate-and-verify done on the save (the glitch is active), and whatever bootstrap state the chosen ACE route
  needs, which the fork plan calls the "bootstrap species".
- A bag reader that reads counts in the Balls and Items pockets.

## Open questions

- Which ACE route and payloads? Settled for English FireRed 1.1 on mGBA
  (`docs/design/FRLG-ACE-Execution.md`): pomeg-letterbombers' Post-E4 route (species 0x0351, done
  by `frlg.ace_setup`) and Sleipnir17's "Get any item" box names with the BIOS-less exit, one
  execution per item into the PC's item storage, then withdrawn to the bag. Proven on mGBA from
  memory for Master Ball, Luxury Ball, Rare Candy, Repel and Escape Rope (x999 each); the
  Switch release is still unverified (its emulator needs adjusted names, per the pomeg FAQ).
- Money and coins have no code in that list: a new code, or dropped from bag prep?
- Checkpoints: decided in review, one template pair (enter the code, trigger) run per item with
  options `item=<slug> withdraw=<n>` from a vetted table.
- Why ACE rather than more `duplicate_item` rounds (one item per round and one Retro Mail)? ACE gives
  a full stack at once and can make items that cannot be bought; duplication needs one held item to
  start from.
- How many: decided in review, the first version withdraws about 50 Master Balls and 300 Luxury
  Balls from each run's 999.
