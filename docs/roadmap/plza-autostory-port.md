# G. Port the PLZA story to GamePilot

Goal: as an exercise in porting a free-moving 3D game, port the fork's Legends: Z-A AutoStory,
including its battle and catch code, to GamePilot, transparently (same steps and timings as the C++).

## Source

The C++ is the plan: branch `plza/lean` (fork PR #644), story rows 01.00 to 03.11, described in
`autostory/plza/UPSTREAM_PLAN.md` on the fork's `agents` branch.

| C++ (under `PokemonLZA/Programs/AutoStory/`) | What it does | GamePilot home |
|---|---|---|
| `StoryData/plza-*.plan.json` (31 plans) | checkpoints as data | `src/games/pokemon/plza/programs/story/plans/` |
| `PokemonLZA_AutoStoryScreenEvents.cpp`, `PokemonLZA_AutoStorySceneMachine.cpp`, `PokemonLZA_AutoStoryConsoleBackend.cpp`, `PokemonLZA_AutoStoryGame.cpp` | screen events and scenes, the story backend | `src/games/pokemon/plza/checkpoints`, `src/pokemon/checkpoints` |
| `Actions/Walks`, `WorldWalks`, `MapLegs` | timed legs, turns after a camera recenter, minimap heading, platform arrival | `src/games/pokemon/plza/actions` |
| `Actions/Catches`, `CatchPlan`, `Zone1` | wild-zone catches, battle then catch | `src/games/pokemon/plza/battle` |
| `Actions/NewGame`, `Starts`, `Autosaves` | new game, start checks from recorded minimaps, autosave points | `src/games/pokemon/plza/actions` |

Related fork PRs: #590 (the shared ball throw helper), #755 and #754 (minimal slices for 01.01 and
01.02), #756 (detectors with tests).

## Rules carried over (from the fork's PLZA runs)

- Checkpoints split at the game's autosave points; the title screen's Up+B+X loads the backup save.
- Run every leg (hold B); walks wait for free control, a scene ending is not control.
- Dialog choices take the top option unless it has a lasting effect; the rival battle at 03.02b may
  be lost and the story goes on.

## First stage: 01.01 only (decided 2026-11-25)

PLZA is the first native Switch game on GamePilot, ahead of Octopath 0 and Sword/Shield (#17): its C++
passed on the console in all ten languages, so a failure points at GamePilot, not at the game. It
shapes the pieces both later games use.

- **Scope.** Checkpoint 01.01 (the platform to MAIN MISSION 01), the cut of fork #754: `wait_for_platform`,
  `set_text_speed_fast`, `walk`, `scene`, `plus_skip`. 01.00 (new game) and 01.02 are later decisions.
- **Engine.** `games/pokemon/plza` links `src/engine` only, through its own `Plza_rules` (zone poses, its own
  actions), after Engine-Boundary PR 4. Readers, actions and the plan file can come before it; nothing
  touches `src/engine` or `src/pokemon/checkpoints` meanwhile. `walk`'s timed legs stay PLZA's own JSON
  until a second game needs the same shape. `plza` joins `family pokemon` in its own PR when battles
  and catches are ported (moves, types, party).
- **Daemon (Engine-Boundary PR 8, claimed by this port).** 8a: `--viewport native`, the whole frame at
  1920x1080 game pixels, so the C++ boxes and 1080p templates carry over. 8b: optional `left_stick` and
  `right_stick` on `press`, [x, y] in -1..1; running is B with the stick, as in
  `PokemonLZA_AutoStoryConsoleBackend.cpp`. Angles become tilts in `Switch_home.Stick_tilt`; the run
  speed-up stays in `games/pokemon/plza`.
- **Reload.** As the reload in `PokemonLZA_AutoStoryConsoleBackend.cpp`: close the game and launch PLZA's
  tile from HOME (`switch_home` learns it from `NintendoSwitch_GameEntry.cpp`), then game menu to in
  game. `Home_screen` keeps the fork's whole-frame boxes and converts them by the daemon's viewport. The
  game autosaves on the platform, so every attempt reloads to it.
- **Tests.** The detector and game tests of fork #644 ported with their modules, a scripted run with a
  walk that never sees its fade (`lost`, no input after it), a wire-log replay of the first passing
  console run. On console B: three passes in a row, each leaving the platform and reaching free control
  in the city after the MAIN MISSION 01 banner. Any language: a faithful port keeps the C++'s handling.

## Steps

1. Readers with their frames (the fork's CommandLineTests frames): dialog, platform, minimap arrow,
   badges, battle and catch screens.
2. Engine fit: PLZA plans decode on `src/pokemon/checkpoints` (the fork's C1-C9 core is PLZA's engine).
3. 01.00-01.01 (new game to the first free control), replayed, then on console B.
4. Battle and catch actions, then rows to 03.11 in order, each with a replay test.

## Open questions

- After 01.01: 01.02 next, or 01.00 (new game)?
- Port the whole 01.00-03.11 or stop at the first catch as the exercise?
