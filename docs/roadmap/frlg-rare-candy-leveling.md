# A1. Rare Candies: duplicate them, then level with them

Goal: turn the Mail Glitch into levels. Duplicate Rare Candies, then a leveling program feeds them to
a chosen Pokemon until a target level, learns the moves the plan names and handles evolution.

## What exists

- **Duplication.** 08-activate-and-verify's `duplicate_item` (`src/games/pokemon/frlg/programs/mail_glitch/plans/08-activate-and-verify.plan.json`)
  runs one round of the C++ `ItemDuplication` loop: the held item +1 in the bag, one Retro Mail used.
  The fork's FRLG story design (`docs/design/AutoStory-FRLG-FutureEvents.md`, fork PR #130, section
  "Item duplication") already names Rare Candies and Nuggets as the reason to have it. Retro Mail is
  sold at the Celadon Dept. Store 4F; 08-activate-and-verify buys it there.
- **Move learning.** The grind checkpoints' `grind` action reads the grinder's moves on the summary, learns one named
  move into a named slot and declines every other move offered.
- **No prior plan** for the leveling program itself.

## Steps

1. **Rare Candy farm** (`frlg.rare_candy_dupe`, one-shot or one checkpoint): from a save where the
   glitch is active, give the Rare Candy holder its candy, buy Retro Mail for N rounds, run
   `duplicate_item` with `count: N`, verify the bag count went up by N, save. Mostly plan data.
2. **Candy leveling action** (`use_rare_candy`, done: `Rare_candy`): open the bag, use a Rare Candy on a party slot, read
   the level-up box, then answer whatever follows: the move-learn prompt (learn, replacing a named
   move, or decline) and the evolution scene (let it run or cancel with B, as the plan says).
3. **Leveling program** (`frlg.candy_leveling`; its loop is the `candy_level` plan action, `Candy_level`): a goal per member (target level, moves to keep, evolve
   yes/no) and a loop of step 2 until the level reader reads the target. Ends with a summary check of
   level, species and moves, then saves.

## Prerequisites

- The Mail Glitch active on the save (08-activate-and-verify done).
- A level reader (missing; see `docs/roadmap.md`, Grinding options) and a species reader after evolution.
- Replay frames of the level-up box, move-learn prompt and evolution scene, recorded on mGBA.

## Open questions

- ~~In what order does the game show the move-learn prompt and the evolution when one candy causes
  both?~~ Settled from the decomp: the level-up stats, then every move of that level, then the
  evolution (cancellable with B held), whose new species may ask for its own moves; then back to the
  bag. The full order is in `Rare_candy`'s doc comment (`src/games/pokemon/frlg/actions/lib/rare_candy.mli`).
- How many candies per run, and how much money for Retro Mail (one per candy)? Nuggets duplicate the
  same way and could pay for the mail.
- Which Pokemon does the user want leveled first (the A4 trapper, A6's catcher, or the story team)?
