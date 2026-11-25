# A6. Dex collection, FireRed exclusives first

Goal: a goal-driven collector that reads the Pokedex, picks what is missing, prepares balls and a
catcher, catches and verifies. The first goal is the Kanto FireRed exclusives.

## Source plans

Two fork plans, both to carry over:

- **The collector**, `autostory/frlg/design/AutoStory-FRLG-Dex-Collection.md` on `agents` (stack
  design S4): read the caught Pokedex; classify each missing species as feasible now, story owned,
  story locked, unsupported, unrouteable or unavailable; pick one recipe and a hunt site (two
  adjacent wild tiles reachable on the map graph, no trainer sight); build one ordinary checkpoint;
  run it; verify with a `dex_entry` read; save; replan. It ends with a completion and blocker report,
  never a loop. Its slices: catalog in PokemonSimulation, Pokedex list reader, Pokedex navigation,
  pure planner, `capture` with a chosen ball and HP-aware weakening, checkpoint factory, a land-wild
  collector (the first usable result), then one method per follow-up (fishing, Surf, Safari, static,
  gifts and trades).
- **The FireRed exclusives preset**, `docs/design/FRLG-DexCollection-Plan.md` (fork PR #776, Track 2):
  13 shinies in Luxury Balls via Wild RNG, plus a Game Corner Scyther via Gift RNG.

| Spot | Method | Species (count) |
|---|---|---|
| Route 8 | grass | Ekans (2), Growlithe (2) |
| Route 7 | grass | Oddish (3) |
| Viridian City pond | Surf | Psyduck (2) |
| Vermilion City shore | Super Rod | Shellder (2) |
| Power Plant | grass | Electabuzz (1) |
| Celadon Game Corner | prize (Gift RNG) | Scyther (1) |

Counts are per evolution line, so a line can be finished later by evolving. Sevii exclusives
(Wooper, Qwilfish, Delibird, Murkrow, Skarmory, per #776) are a second phase, after A2.

## Ball and catcher plan

From #776 section 4.1, the start state the collector checks before moving:

- **Catcher in party slot 1**: Parasect, Lv 100, with Spore and False Swipe, holding a Lum Berry or
  Leftovers. Turn 1 Spore, turn 2 False Swipe, then Luxury Balls; Spore again on waking. #776 works
  out that Ekans, Oddish, Psyduck, Growlithe and Shellder are sure catches at 1 HP asleep, and
  Electabuzz about 36% per ball.
- **Balls**: Master Balls in slot 1 for calibration catches (restored by the reset), Luxury Balls in
  slot 2 for the shinies.
- **Field moves**: Fly and Surf users, a Sweet Scent user last; Super Rod registered.
- **Bag**: Max Repels, Escape Ropes, coins for the Scyther.
- **One free party slot** (Wild and Gift RNG need one).

Where they come from: A3's ACE preset (balls, Rare Candies, the Parasect), or without ACE, A1's
leveling program for the Parasect and bought balls.

## Steps

1. Pokedex list reader and navigation (`src/games/frlg/readers`, probes, not the C++ OCR).
2. The catalog as PokemonSimulation data; the pure planner in OCaml with table tests.
3. `capture` with `ball=` and the Spore/False Swipe catcher loop (shared with A4).
4. Land-wild collector on mGBA from a post-game save: non-shiny, Kanto caught set, one target at a
   time. This is the first usable result, and it can also fill the 60 caught A2 needs.
5. The exclusives preset with shinies, once A5's Wild RNG and the Gift RNG are ported.

## Open questions (from both plans, still open)

- Weakening: the collector plan recommends no False Swipe at first (better balls and a catch rate
  filter); #776 builds on a False Swipe Parasect. Which first?
- May the collector overwrite the post-game save, or test mode only until verified?
- LeafGreen and the National Dex are later goals; trades and events stay disabled.
