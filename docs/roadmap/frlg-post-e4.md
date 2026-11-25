# FRLG after the Elite Four

Six milestones that start from a post-game FireRed save (the Mail Glitch's save, or the C++ story's
Hall of Fame save). All live in `src/games/frlg`, run on mGBA first and then on the Switch, and use
the checkpoint runner and story engine the Mail Glitch built. Together they are slice S4.

| # | Milestone | Needs first | Page |
|---|---|---|---|
| A1 | Duplicate Rare Candies and a leveling program (candies, target moves, evolution) | Mail Glitch (08-activate-and-verify's `duplicate_item`) | [frlg-rare-candy-leveling.md](frlg-rare-candy-leveling.md) |
| A2 | Sevii Islands story: One to Seven Island, Ruby and Sapphire, National Dex | post-game save; Cut and Surf users (Waterfall is taught on the way) | [frlg-sevii-islands.md](frlg-sevii-islands.md) |
| A3 | ACE: stock Master Balls and Luxury Balls | Mail Glitch; FRLG naming-screen typer | [frlg-ace-balls.md](frlg-ace-balls.md) |
| A4 | Collect the legendaries | A2 for Moltres, Mewtwo and the beast; balls from A3 | [frlg-legendaries.md](frlg-legendaries.md) |
| A5 | Port Wild RNG and Static RNG from PA/CC | Switch timing gate for 60 fps presses | [frlg-rng-port.md](frlg-rng-port.md) |
| A6 | Dex collection, FireRed exclusives first, with a ball and catcher plan | A1 or A3 for the catcher, A5 for shinies | [frlg-dex-exclusives.md](frlg-dex-exclusives.md) |

## Suggested order

1. **A1** first: it reuses 08-activate-and-verify's action with a different item and count, and its leveling program
   is what A3/A6's catcher and A4's trapper need if ACE is not used.
2. **A5** next, in parallel with A1: the RNG math is pure and has the C++ as oracle; it gates the
   shiny parts of A4 and A6.
3. **A3**, then **A6** (its first usable slice is a land-wild collector that needs neither ACE nor
   RNG).
4. **A2**, then **A4**: most legendaries sit behind the Sevii story.

The order is a proposal; the parent issue's task list is where it is decided.

## Shared gaps

From the Mail Glitch work (`docs/roadmap.md`, Phase 3 and mg-04): a level reader, HP and PP readers,
a foe species reader, a party species reader in place of the reckoned party, and `capture` with a
chosen ball. Most milestones need some of these; build each once, in `src/games/frlg/readers`.
