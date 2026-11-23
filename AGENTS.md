# AGENTS.md

GamePilot automates games through three layers (design: `docs/design/Layered-Automation-Stack.md`):

- `daemon/` (C++): I/O (frame source, input sink, one clock) and probes (pixels -> numbers).
  Glue only: no thresholds, no state machines, no game names. Its own CMake build,
  `clang-format`, strict warnings.
- `src/` (OCaml 5.2+, dune): one dune project. Every library is `<name>/lib` with its tests in
  `<name>/test`.
  - `base/`: pure, game-agnostic code with no effects (`wire`: the protocol codec).
  - `core/`: the effects programs use (`effects`) and their handlers (`session`, `live`, `replay`).
  - `pokemon/`: code shared by Pokemon games (navigation grid, story plans and their engine).
  - `games/<game>/`: `readers/`, `actions/`, `maps/`, `story/`, and `programs/<program>/`.
  - `bin/`: the `gamepilot` command.
- `contracts/`: golden JSON-RPC messages both sides must parse. The only thing they share.
  Formatted by `tools/fmt_json.py` (one key per line, lists of scalars inline).

## Hard rules

- **Names say what a thing is or does.** No catch-all modules or folders (`helpers`, `utils`, `common`, `misc`):
  a function with no obvious home gets a module named for its job. The C++ folder names on the
  fork are a guide where they are informative.
- **OCaml passes `sh tools/lint_ocaml.sh`** (`lint/`, configured by `tools/ocaml_lint.conf`): function
  length, nesting, magic numbers, file length, `.mli` for every `lib/` module, layer boundaries;
  complexity is advisory. Waive only in `tools/ocaml_lint_exceptions.conf`, with a reason.
- **No C in OCaml.** No `foreign_stubs`, `foreign_archives`, `extra_objects` or `ctypes` in any
  `dune` file (`tools/lint_dune.sh`). Every opam dependency is listed in
  `tools/opam-allowlist.txt`. The Windows CI build is the real gate.
- **Programs use only our effect set** (`submit`, `await`, `race`, `now`, `read`), never an I/O
  library directly. The real handler is stdlib only.
- **Swappable parts sit behind one boundary each**: I/O backend, probes, effect handler, RNG.
- **Submodules are read-only.** `third_party/Arduino-Source` tracks the fork branch
  `gamepilot/base` and `third_party/Packages` tracks upstream: never edit them here.
- **`gamepilot/base` is the whole overlay**: fork `main` plus the fewest, smallest patches
  GamePilot needs (today one: `CoreLib` exports its usage requirements). The daily sync
  (`~/Projects/pa-tools/sync_branches.py`) merges fork `main` into it; it is never merged back.
  A patch goes there as one commit with a message saying why GamePilot needs it, then the
  submodule is bumped here. Prefer a change in GamePilot over a patch.
- The daemon uses `CoreLib` only, through upstream's `SourceFiles.cmake` and `CoreLib.cmake`.
  Vision is OpenCV. Paths go through `Common/Cpp/Filesystem` (UTF-8 on Windows).
- Nothing here is published upstream. PRs: `--repo dayfine/GamePilot --draft`.
- The FireRed ROM, its path and its hash never enter this repo or any log.
- Console B is shared with the Arduino-Source lab app under the one-train rule (`lablock.sh`).

## Agents

Harness from `dayfine/agent-harness` (`.agents/`, `dev/lib/`, `bin/`). `pr-maintenance` and
`reviewer` were imported from Arduino-Source's `agents` branch and still name its paths in places;
adapt them before first use.
