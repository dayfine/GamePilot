# Running on mGBA

mGBA is where every FireRed program is tested before it runs on the Switch. A Lua script inside
mGBA (the bridge) lets the daemon hold the emulator frame by frame, so a run on mGBA is exact and
can go faster than the console.

## What you need

- [mGBA](https://mgba.io/) 0.10.5 or later, with its scripting support (the official builds have it).
- Your own FireRed ROM. None is included in or needed by this repository.
- The bridge, `bridge.lua`, from `lab/mgba/` on the `agents` branch of
  [dayfine/Arduino-Source](https://github.com/dayfine/Arduino-Source/tree/agents/lab/mgba).
  Its `PROTOCOL.md` describes the line protocol the daemon speaks to it.

## Set up the mGBA folder

Pick a folder for GamePilot's mGBA (`GAMEPILOT_MGBA_DIR`, below). Put a copy of your ROM there,
and a `run_bridge.lua` that sets the bridge's port and loads it:

```lua
MGBA_BRIDGE_CONFIG = {
    host = "127.0.0.1",
    port = 47810,
    port_tries = 1,
    mode = "paced",
}
dofile("/path/to/bridge.lua")
```

`paced` mode lets the daemon grant one frame at a time. The runner starts mGBA with this script, and
its saves go to the same folder.

## Load the bridge by hand

For a first try or a one-off program, start mGBA yourself: load the ROM, then Tools > Scripting,
then File > Load script, and pick `bridge.lua` (or your `run_bridge.lua`). The scripting window
prints `[mgba-link] MgbaLink v1 ... listening on 127.0.0.1:PORT`. To load a changed script, use
File > Reset in that window first.

`bridge.lua` alone listens on the first free port from 47801. Pass that port to the daemon as
`--mgba-port` (`daemon/README.md`).

## Settings

`run/run_checkpoints_on_mgba.sh` starts mGBA, runs `gamepilot run` against it and closes it
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
| `GAMEPILOT_WATCH_LISTEN` | the watch pages' address; `0.0.0.0` opens them to the LAN | `127.0.0.1` |
| `GAMEPILOT_LAB_GAME` | the lab console's game id (its HOME tile, its lab panel) for `ctl park`/`resume`, `console`, `switch-devices` | the one game with Switch HOME data (`frlg`) |

`gamepilot run` reads `GAMEPILOT_STATES` and `GAMEPILOT_RUNS` too (`--states` and
`--runs-dir` override them).

## Run checkpoints

```sh
sh run/run_checkpoints_on_mgba.sh frlg.mail_glitch \
    --from 01-celadon-setup --to 01-celadon-setup --mode testing
```

Each checkpoint starts from its save state, `$GAMEPILOT_STATES/<ID>.start.ss`. The runner passes
`--watch`, so the run has its own page (`docs/getting-started.md`, What you see). `--speed S` runs
the game S times as fast. One run at a time: a second runner waits for the first.

The runner starts mGBA with `open`, so it is macOS only today. On macOS, turn App Nap off for
mGBA once, so a hidden mGBA keeps full speed:

```sh
defaults write com.endrift.mgba-qt NSAppSleepDisabled -bool YES
```

Each program's page in `docs/guide/` gives its own commands and the states it needs.
