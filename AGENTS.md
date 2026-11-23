# AGENTS.md

GamePilot automates games through three layers (design: `docs/design/Layered-Automation-Stack.md`):

- `daemon/` (C++): I/O (frame source, input sink, one clock) and probes (pixels -> numbers).
  Glue only: no thresholds, no state machines, no game names. Its own CMake build,
  `clang-format`, strict warnings.
- `programs/` (OCaml 5.2+, dune): readers, actions, checkpoints, stories, sim and replay.
- `contracts/`: golden JSON-RPC messages both sides must parse. The only thing they share.

## Hard rules

- **No C in OCaml.** No `foreign_stubs`, `foreign_archives`, `extra_objects` or `ctypes` in any
  `dune` file (`tools/lint_dune.sh`). Every opam dependency is listed in
  `tools/opam-allowlist.txt`. The Windows CI build is the real gate.
- **Programs use only our effect set** (`submit`, `await`, `race`, `now`, `read`), never an I/O
  library directly. The real handler is stdlib only.
- **Swappable parts sit behind one boundary each**: I/O backend, probes, effect handler, RNG.
- **Submodules are read-only.** `third_party/Arduino-Source` (fork `main`) and
  `third_party/Packages`: never edit them here. Fix in the fork, then bump.
- The daemon uses `CoreLib` only, through upstream's `SourceFiles.cmake` and `CoreLib.cmake`.
  Vision is OpenCV. Paths go through `Common/Cpp/Filesystem` (UTF-8 on Windows).
- Nothing here is published upstream. PRs: `--repo dayfine/GamePilot --draft`.
- The FireRed ROM, its path and its hash never enter this repo or any log.
- Console B is shared with the Arduino-Source lab app under the one-train rule (`lablock.sh`).

## Agents

Harness from `dayfine/agent-harness` (`.agents/`, `dev/lib/`, `bin/`). `pr-maintenance` and
`reviewer` were imported from Arduino-Source's `agents` branch and still name its paths in places;
adapt them before first use.
