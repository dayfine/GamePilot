# G. Port the PLZA story to GamePilot

Goal: as an exercise in porting a free-moving 3D game, port the fork's Legends: Z-A AutoStory,
including its battle and catch code, to GamePilot, transparently (same steps and timings as the C++).

## Source

The C++ is the plan: branch `plza/lean` (fork PR #644), story rows 01.00 to 03.11, described in
`autostory/plza/UPSTREAM_PLAN.md` on the fork's `agents` branch.

| C++ (under `PokemonLZA/Programs/AutoStory/`) | What it does | GamePilot home |
|---|---|---|
| `StoryData/plza-*.plan.json` (31 plans) | checkpoints as data | `src/games/plza/programs/story/plans/` |
| `ScreenEvents`, `SceneMachine`, `ConsoleBackend`, `Game` | screen events and scenes, the story backend | `src/games/plza/checkpoints`, `src/pokemon/checkpoints` |
| `Actions/Walks`, `WorldWalks`, `MapLegs` | timed legs, turns after a camera recenter, minimap heading, platform arrival | `src/games/plza/actions` |
| `Actions/Catches`, `CatchPlan`, `Zone1` | wild-zone catches, battle then catch | `src/games/plza/battle` |
| `Actions/NewGame`, `Starts`, `Autosaves` | new game, start checks from recorded minimaps, autosave points | `src/games/plza/actions` |

Related fork PRs: #590 (the shared ball throw helper), #755 and #754 (minimal slices for 01.01 and
01.02), #756 (detectors with tests).

## Rules carried over (from the fork's PLZA runs)

- Checkpoints split at the game's autosave points; the title screen's Up+B+X loads the backup save.
- Run every leg (hold B); walks wait for free control, a scene ending is not control.
- Dialog choices take the top option unless it has a lasting effect; the rival battle at 03.02b may
  be lost and the story goes on.

## Steps

1. Readers with their frames (the fork's CommandLineTests frames): dialog, platform, minimap arrow,
   badges, battle and catch screens.
2. Engine fit: PLZA plans decode on `src/pokemon/checkpoints` (the fork's C1-C9 core is PLZA's engine).
3. 01.00-01.01 (new game to the first free control), replayed, then on console B.
4. Battle and catch actions, then rows to 03.11 in order, each with a replay test.

## Open questions

- Which language for the first run (the fork's final check was Spanish)?
- Port the whole 01.00-03.11 or stop at the first catch as the exercise?
