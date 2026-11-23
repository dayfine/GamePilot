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
