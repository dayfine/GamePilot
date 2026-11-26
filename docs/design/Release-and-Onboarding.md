# Release packaging, setup, and local UI launcher (2026-11-26)

Tracking issue: [#294](https://github.com/dayfine/GamePilot/issues/294). Builds on
`docs/design/Watch-Page.md` and `docs/design/Control-UI.md`.

Today GamePilot runs from a git checkout with opam, dune, CMake, OpenCV, and three submodules.
This note describes how a new user installs a release, checks that their hardware is ready, and
launches programs without cloning the repository or hand-typing device flags.

## 1. Release archive (what a user downloads)

Each tagged release (`v0.x.y`) publishes one self-contained archive per target platform:

- `gamepilot-v0.x.y-macos-arm64.tar.gz`
- `gamepilot-v0.x.y-linux-x86_64.tar.gz`
- `gamepilot-v0.x.y-windows-x86_64.zip`

Inside the archive:

```text
gamepilot-v0.x.y/
  gamepilot                  # OCaml CLI + local control-plane hub (zero runtime deps)
  bin/
    gamepilot_daemon         # C++ daemon (CoreLib compiled in; OpenCV static or bundled beside it)
  share/gamepilot/
    plans/                   # src/games/**/programs/*/plans/*.plan.json, places, fragments
    assets/                  # src/games/**/assets/* (templates, seed tables, mart stocks, icons)
    maps/                    # runtime subset of PokemonSimulation maps
    packages/                # runtime OCR/resource subset from third_party/Packages
  README.txt
```

**Why two binaries, not one.** `gamepilot` (OCaml) and `gamepilot_daemon` (C++) stay separate
executables inside one folder. Packing a native C++ binary inside the OCaml executable and
extracting it at runtime triggers macOS Gatekeeper and Windows Defender warnings for little gain.
`gamepilot` already locates its daemon; in a release bundle it defaults to
`<exe_dir>/bin/gamepilot_daemon` before falling back to `$GAMEPILOT_DAEMON` or the dev build path.

**Locating bundled data.** `Repo_io.Repo_files.locate` currently walks up from `cwd` looking for
`src/...` and `third_party/...`. Adding a fallback to `<exe_dir>/share/gamepilot/...` (and
`$GAMEPILOT_SHARE`) makes the extracted archive work from any working directory with no git repo,
opam switch, or CMake build.

## 2. Controller firmware (`Arduino-Source`)

Users do **not** download or build `Arduino-Source` to run GamePilot:

- `CoreLib` is compiled directly into `gamepilot_daemon` during the release build.
- Anyone coming from Pokemon Automation / SerialPrograms (PA/CC) already has compatible controller
  firmware flashed on their ESP32 / Pico / AVR board and needs no firmware step.
- Brand-new hardware users only need to flash their microcontroller once. `gamepilot setup` and
  `README.txt` point to PA/CC's firmware flashing instructions rather than bundling a flasher in v1.

## 3. First-run flow: `gamepilot setup` and `gamepilot doctor`

After unzipping the archive, a user runs:

```sh
./gamepilot setup
```

1. **Discover hardware** (reusing `gamepilot switch-devices`): enumerates capture cards and serial
   controller boards, plus optional mGBA bridge configuration.
2. **Assign named consoles**: writes `consoles.json` under the per-user data directory
   (`Repo_io.Repo_files.data_dir "GAMEPILOT_CONFIG" "config"`, defaulting to
   `~/.local/share/gamepilot/config/consoles.json`, or `%USERPROFILE%\.local\share\gamepilot\config\consoles.json`
   on Windows):

   ```json
   {
     "consoles": [
       {
         "id": "console-a",
         "name": "Console A",
         "backend": "switch",
         "serial": "<port>",
         "capture": "<device>"
       },
       {
         "id": "mgba",
         "name": "mGBA (local)",
         "backend": "mgba",
         "mgba_port": 47810
       }
     ]
   }
   ```

3. **Optional game settings**: prompts for or points to per-game local files such as FRLG's
   `trainer_ids.json` (TID/SID) so users never edit plan JSONs.
4. **Non-intrusive health check** (`gamepilot doctor`): for each configured console, starts
   `gamepilot_daemon` briefly to verify the serial handshake and grab a single frame (checking
   non-black signal, resolution, and frame rate) without pressing any game buttons. Prints a
   per-console pass/fail summary.

CLI commands can then target a console by name (`gamepilot run frlg.supplies --console console-a ...`)
instead of repeating `--backend`, `--serial`, and `--capture`.

## 4. Console status page and launching from the UI (`gamepilot ui`)

GamePilot already ships a local watch hub (`127.0.0.1:47901`, or `--listen 0.0.0.0` with a Stop
token) and per-run watch pages (`docs/design/Watch-Page.md`). Promoting the hub to a persistent
local server (`gamepilot ui`) gives new users a single browser control plane:

```text
browser  <-- GET  /                 (console status + program launcher)
         <-- GET  /api/consoles     (consoles.json + live health / running state / thumbnail)
         <-- GET  /api/programs     (Program_registry + Run_options.declared + checkpoints)
         --- POST /api/preflight    (runs `gamepilot run ... --preflight`, returns needs table)
         --- POST /api/runs         (spawns `gamepilot run ... --watch`, returns watch URL)
         --- POST /api/runs/:id/stop
```

### Readiness view (Consoles)

Lists every configured console (`Console A`, `Console B`, `mGBA`) as a card showing:

- **Status**: `Ready`, `Running <program>` (with link to its live watch page), `Needs attention`
  (last run failed, link to failure frame/log), or `Offline` (serial or capture missing).
- **Live health**: serial link, capture signal, and an on-demand preview frame.
- **Quick actions**: `Test` (runs the single-frame + handshake check), `Park` (`console-park`),
  and `Stop` (when running).

### Launching a program

- **Dynamic form from `Program_registry`**: picking a program renders its options directly from
  `Run_options.declared` (`One_of` as a dropdown, `Int_range` as a bounded number input, `Text` as
  a text input, `Default` pre-filled, `Required` validated before launch), plus optional `--from` /
  `--to` checkpoint selectors. No separate UI schema to drift out of sync.
- **Preflight before pressing**: clicking `Preflight` runs `gamepilot run <program> --preflight`
  and shows the green/red needs table inline.
- **One runner underneath**: clicking `Run` dispatches `gamepilot run <program> --console <id> --watch ...`
  as a child process under the hub, enforcing one active run per console (`AGENTS.md`: only one
  program drives a Switch at a time), and opens the existing live watch page.

CLI and UI execute the exact same runner, preflight, and `--options` validation.

## 5. Release pipeline (GitHub Actions)

Triggered on version tags (`v*`) or manual workflow dispatch:

1. **Build matrix** (`macos-latest`, `ubuntu-latest`, `windows-latest`): builds `gamepilot`
   (OCaml) and `gamepilot_daemon` (C++ with CoreLib + OpenCV).
2. **Stage**: copies binaries and required `share/gamepilot/` directories into the release tree.
3. **Out-of-tree smoke test**: extracts the archive into an empty temp directory outside the git
   repo and runs:
   - `./gamepilot programs` (verifies registry and bundled plan discovery)
   - `./gamepilot --help` and `./bin/gamepilot_daemon --help` (verifies dynamic libraries on
     macOS/Linux/Windows)
   - An offline replay / plan-load check so any missing bundled asset fails the release before
     upload.
4. **Publish**: uploads the three platform archives and `SHA256SUMS.txt` to the GitHub Release.

## 6. Implementation order

1. `Repo_files` packaged-share fallback + staging script + out-of-tree smoke test.
2. `consoles.json` + `--console <id>` + `gamepilot setup` / `gamepilot doctor`.
3. `gamepilot ui` hub upgrade (console status API/cards + `POST /api/runs` & `/api/preflight`
   backed by `Program_registry`).
4. GitHub Actions release workflow on `v*` tags.
