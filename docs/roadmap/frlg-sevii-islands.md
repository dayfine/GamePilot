# A2. Sevii Islands story

Goal: from a post-game save, play the Sevii Islands story to the end of the network machine: One to
Three Island, the National Dex, the Ruby and the Sapphire, so Cerulean Cave, Moltres and the
roaming beast (A4) and the Sevii exclusives (A6) open.

## Source plan

The fork's FRLG story design, `docs/design/AutoStory-FRLG-FutureEvents.md` (fork PR #130), drafts
every row; the earlier summary is `pokemon_sv/FRLG_FUTURE_EVENTS_DRAFT_20261101.md` on `agents`. The
C++ story on the fork declines Bill after Blaine (user decision; `AutoStory-FRLG-Path-to-E4.md`), so
on our saves all of this is post-game. The rows to port:

| Segment | Rows | Content |
|---|---|---|
| 11 | 11.01-11.04 | Bill at the Cinnabar Center, One Island (Tri-Pass, Meteorite), Two Island, Berry Forest and the Hypno battle, back to Cinnabar |
| 15 | 15.01-15.08 | National Dex at Oak's lab (needs 60 caught), Celio's Ruby request, Mt. Ember and the Ruby, Rainbow Pass, Icefall Cave and HM07 Waterfall, Lorelei, Five Island, the Dotted Hole |
| 16 | 16.01-16.03 | Rocket Warehouse (passwords, spinner maze, admins, Gideon), the Sapphire, Celio's machine |

Those rows are symbolic (anchors like `@OneIsland.center_counter`, no coordinates) and unverified on a
console. The fork notes that PC storage is off on the Sevii Islands until a later flag.

## Steps

1. **Maps.** Sevii maps, ferry warps and the cave puzzles (Icefall Cave ice, Rocket Warehouse
   spinners) in PokemonSimulation, the same way Kanto's are. Nothing in GamePilot until they exist.
2. **Ferry action** (`travel_ferry`): Vermilion or island harbors, destination menu, arrival check.
3. **Checkpoints**, one per row, as `src/games/frlg/programs/sevii/plans/*.plan.json` on the story
   engine, each with its mGBA save at its start; battles go through the scripted battle runner.
4. **60 caught gate** for 15.01: the National Dex needs 60 species caught. A6's Pokedex reader checks
   it; if it is short, A6's collector runs first.

## Open questions

- Is the save under 60 caught? The post-game save had a small Pokedex, so 15.01 likely waits on A6.
- Hypno, Gideon, the admins and Lorelei's double battle: which team, and does any of them need a sim
  in PokemonSimulation first (as the Elite Four did)?
- Run Sevii on mGBA only until it is green, then on console B, as the Mail Glitch did?
