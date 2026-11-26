# GamePilot

Layered game automation. A small C++ daemon owns the console (capture card, controller board via
PABotBase2, mGBA, or recorded frames) and serves probe measurements over JSON-RPC; game programs
are written in OCaml and run unchanged against the console, a replay, or a simulation.

**[Get started](docs/getting-started.md)**: build it, run a first program on mGBA and watch it.

- Running on mGBA: [docs/mgba.md](docs/mgba.md). On the Switch: [docs/switch-bring-up.md](docs/switch-bring-up.md).
- How to run each program: [docs/guide/README.md](docs/guide/README.md)
- Design: `docs/design/Layered-Automation-Stack.md`
- Engine boundary (what is game-agnostic, how a second game plugs in): `docs/design/Engine-Boundary.md`
- Roadmap: `docs/roadmap.md`
- Rules for contributors and agents: `AGENTS.md`

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

## Sources

- The maps come from [PokemonSimulation](https://github.com/dayfine/PokemonSimulation) (MIT).
- The game data, font glyphs, item and species names are derived from the
  [pret/pokefirered](https://github.com/pret/pokefirered) decompilation (`src/games/pokemon/frlg/assets/extract/extract_frlg_*.py`).
- The test screenshots are captures of the games, kept for testing the readers.
- Pokémon is © Nintendo, Game Freak and Creatures. This project is not affiliated with or endorsed
  by them.

## License

MIT, see `LICENSE`. The submodules under `third_party/` keep their own licenses.
