# GamePilot

Layered game automation. A small C++ daemon owns the console (capture card, controller board via
PABotBase2, mGBA, or recorded frames) and serves probe measurements over JSON-RPC; game programs
are written in OCaml and run unchanged against the console, a replay, or a simulation.

- Design: `docs/design/Layered-Automation-Stack.md`
- Roadmap: `docs/roadmap.md`
- Rules for contributors and agents: `AGENTS.md`

```
git clone --recurse-submodules https://github.com/dayfine/GamePilot
```

## Built on

GamePilot stands on these projects, used as read-only submodules under `third_party/`:

- **[Pokémon Automation Arduino-Source](https://github.com/PokemonAutomation/Arduino-Source)**
  (MIT, © Alexander J. Yee and contributors), through the fork branch `dayfine/Arduino-Source:gamepilot/base`.
  The daemon links its `CoreLib`: the PABotBase2 controller protocol, controller scheduling, JSON
  and file I/O. Much of GamePilot's navigation and FRLG code is ported from its AutoStory work.
- **[Pokémon Automation Packages](https://github.com/PokemonAutomation/Packages)**: image templates
  and other resources.
- **[PokemonSimulation](https://github.com/dayfine/PokemonSimulation)** (MIT): maps and the route
  simulation that GamePilot's plans are checked against.
- Game data (maps, trainer parties, EV yields) comes from the [pret](https://github.com/pret)
  decompilation projects, through PokemonSimulation.

## Running on mGBA

`tools/run_checkpoints_on_mgba.sh` starts mGBA, runs `gamepilot checkpoints` against it and closes it
again. It takes its paths from the environment, or from `~/.config/gamepilot/env` (one
`export NAME=value` per line; `GAMEPILOT_ENV_FILE` names another file), and prints the ones in use:

| Variable | What | Default |
|---|---|---|
| `GAMEPILOT_ROM` | your FireRed ROM | the one `.gba` in `GAMEPILOT_MGBA_DIR` |
| `GAMEPILOT_MGBA_DIR` | mGBA folder: `run_bridge.lua`, saves | `~/.local/share/gamepilot/mgba` |
| `GAMEPILOT_MGBA_APP` | the mGBA app | `/Applications/mGBA.app` |
| `GAMEPILOT_STATES` | checkpoint start states, `<ID>.start.ss` | `~/.local/share/gamepilot/states` |
| `GAMEPILOT_RUNS` | run records, one folder per run | `~/.local/share/gamepilot/runs` |
| `GAMEPILOT_BIN` | the `gamepilot` binary | `src/_build/default/bin/gamepilot.exe` |

`gamepilot checkpoints` reads `GAMEPILOT_STATES` and `GAMEPILOT_RUNS` too (`--states` and
`--runs-dir` override them). No ROM is included in or needed by this repository; bring your own.

## Sources

- The maps come from [PokemonSimulation](https://github.com/dayfine/PokemonSimulation) (MIT).
- The game data, font glyphs, item and species names are derived from the
  [pret/pokefirered](https://github.com/pret/pokefirered) decompilation (`tools/extract_frlg_*.py`).
- The test screenshots are captures of the games, kept for testing the readers.
- Pokémon is © Nintendo, Game Freak and Creatures. This project is not affiliated with or endorsed
  by them.

## License

MIT, see `LICENSE`. The submodules under `third_party/` keep their own licenses.
