# AGENTS.md

GamePilot automates games through three layers (design: `docs/design/Layered-Automation-Stack.md`):

- `daemon/` (C++): I/O (frame source, input sink, one clock) and probes (pixels -> numbers).
  Glue only: no thresholds, no state machines, no game names. Its own CMake build,
  `clang-format`, strict warnings.
- `src/` (OCaml 5.2+, dune): one dune project. Every library is `<name>/lib` with its tests in
  `<name>/test`.
  - `base/`: pure, game-agnostic code with no effects (`wire`: the protocol codec).
  - `core/`: the effects programs use (`effects`) and their handlers (`session`, `live`, `replay`);
    `live_run`: a run's daemon, its watch page and hub, and one checkpoint run in its own daemon,
    shared by every game's series runner.
  - `engine/`: the game-agnostic checkpoint engine (`docs/design/Engine-Boundary.md`). Its
    `checkpoints/` libraries: `rules` (`GAME_RULES`, what a game family gives the engine),
    `promise` (promises, counts, money), `plan` (types, decoding, text), `run` (one checkpoint:
    handlers, trials, event progress), `series` (chains, order, rounds), `expand` (plan JSON
    rewrites), `watch` (a plan's run on the watch page) and `make` (`Engine_checkpoints.Make`, the engine applied to a family's rules). It
    names no game, grid or Pokémon type.
  - `pokemon/`: code shared by Pokemon games: the navigation grid, and in `checkpoints/` the
    Pokémon rules (`rules`: grid poses, Pokémon actions, postconditions), the engine applied to them
    (`instance`: `Pokemon_checkpoints`), the declared end of a checkpoint (`checkpoint_end`), who
    goes to the PC when a chain needs party room (`room_policy`), console runs
    (`series`) and place-route rewrites (`expand`).
  - `games/<game>/` (or `games/pokemon/<game>/`, as PLZA): `readers/`, `actions/`, `maps/`,
    `checkpoints/`, and `programs/<program>/`.
  - `program_registry/`: every program's descriptor (game, group, name, doc, checkpoints folder,
    backends), as PA/CC's program list. A new program registers there (`docs/programs/README.md`).
  - `bin/`: the `gamepilot` command.
- `protocol/`: golden JSON-RPC messages both sides must parse. The only thing they share.
  Formatted by `dev/lint/fmt_json.py` (one key per line, lists of scalars inline).

## Hard rules

- **Names say what a thing is or does.** No catch-all modules or folders (`helpers`, `utils`, `common`, `misc`):
  a function with no obvious home gets a module named for its job. The C++ folder names on the
  fork are a guide where they are informative.
- **What a deciding module reads and does in the game is its `game_steps`.** One record,
  `<Module>.game_steps`, verb-phrase fields; builders `<context>_game_steps` (or `<Module>_steps.make`),
  test fakes `fake_game_steps`. Never `rig`, `driver`, `handlers`, `ops` or `callbacks`; `deps` only
  for a struct that holds external resources or connections.
- **OCaml passes `sh dev/lint/lint_ocaml.sh`** (`dev/lint/`, configured by `dev/lint/ocaml_lint.conf`): function
  length, nesting, magic numbers, file length, `.mli` for every `lib/` module, layer boundaries,
  no exceptions; complexity is advisory. Waive only in `dev/lint/ocaml_lint_exceptions.conf`,
  with a reason.
- **Errors are values.** Code under `src/` (tests aside) returns a `Result`: no `exception`,
  `raise`, `failwith`, `invalid_arg` or `try`/`match ... with exception` (`no_exceptions` in
  `dev/lint/`). The one kept exception is the effects boundary (`Effects.Rpc_error`,
  `Disconnected`, `Stop_requested`, `Replay.Divergence`), confined to `core/effects`, `session`,
  `live`, `replay` and the runner that catches them. Today's other uses are waived file by file in
  `dev/lint/ocaml_lint_exceptions.conf`; that list only shrinks.
- **No C in OCaml.** No `foreign_stubs`, `foreign_archives`, `extra_objects` or `ctypes` in any
  `dune` file (`dev/lint/lint_dune.sh`). Every opam dependency is listed in
  `dev/lint/opam-allowlist.txt`. The Windows CI build is the real gate.
- **Programs use only our effect set** (`submit`, `await`, `race`, `now`, `read`), never an I/O
  library directly. The real handler is stdlib only.
- **Swappable parts sit behind one boundary each**: I/O backend, probes, effect handler, RNG.
- **Port the C++ transparently.** A port of fork code keeps the C++ behaviour, steps, order and
  timings, and each module's doc comment names the C++ file(s) it comes from, so a reader can lay the
  two side by side. Improvements and reshaping come later, in their own PRs. Where we deliberately
  differ (a missing reader, a new strategy), say so in the doc comment.
- **Every checkpoint goes through the checkpoint runner** (`engine/checkpoints/run`) and its dev loop: run
  from the checkpoint's start state, verify its end state, retry, record. Programs run in order
  (01-celadon-setup → 08-activate-and-verify), each tested on mGBA before it runs on the Switch.
  A game with no emulator (PLZA, Sword/Shield, Octopath 0) is tested instead by its reader and
  game tests, a scripted run (including a lost walk) and a wire-log replay of a console run in CI,
  then three console passes in a row.
- **Submodules are read-only.** `third_party/Arduino-Source` tracks the fork branch
  `gamepilot/base`, `third_party/Packages` tracks upstream, and `third_party/PokemonSimulation`
  tracks its `main`: never edit them here. Maps are read from PokemonSimulation
  (`data/games/<game>/maps`), never copied; a map change lands there first. A program's own
  checkpoint plans live with it (`games/<game>/programs/<program>/plans/`) and are refined here.
- **`gamepilot/base` is the whole overlay**: fork `main` plus the fewest, smallest patches
  GamePilot needs (today one: `CoreLib` exports its usage requirements). A daily sync
  merges fork `main` into it; it is never merged back.
  A patch goes there as one commit with a message saying why GamePilot needs it, then the
  submodule is bumped here. Prefer a change in GamePilot over a patch.
- The daemon uses `CoreLib` only, through upstream's `SourceFiles.cmake` and `CoreLib.cmake`.
  Vision is OpenCV. Paths go through `Common/Cpp/Filesystem` (UTF-8 on Windows).
- Nothing here is published upstream. PRs: `--repo dayfine/GamePilot --draft`.
- The FireRed ROM, its path and its hash never enter this repo or any log.
- The Switch (a Switch with a capture card and a controller board) is shared with other
  automation: only one program may drive the console at a time.
- Machine-specific paths come from environment variables (`GAMEPILOT_*`, see `README.md`),
  never from a home path in code, docs or tests.

## PR gate loop

Each PR goes through, in order: **CI green → qc-structural at the tip → squash merge**. A design
doc, or a PR reworked twice, waits for the user's review instead. A PR that changes structure merges
on its APPROVED verdict like any other (user, 2026-11-24); the main session holds one now and then
for the user to spot check.

- A PR changes structure when it adds, deletes or renames a library module or a `dune` file under
  `src/`; changes the `.mli` of a library shared across games (`src/base`, `src/core`,
  `src/pokemon`); changes a format (the plan, goal or places format, `protocol/`, a `*_decode.ml`);
  or has had two NEEDS_REWORK verdicts. Rename-only PRs count, and so do design docs (`docs/design/`).
  The gate marks these `merge (structural: <reason>)`, so they are easy to pick for a spot check.

- qc-structural (`.agents/agents/qc-structural.md`, rows in
  `.agents/rules/qc-structural-authority.md`) runs only on green CI. It posts its verdict as a
  COMMENT review: `Reviewed SHA: <sha>` on line 1, `## Verdict` then `APPROVED` or `NEEDS_REWORK`.
  Its FLAGs are questions for the user and do not block.
- A verdict holds for the SHA it names. A rework commit invalidates it: review the new tip.
- Docs-only PRs (every file `.md` or under `docs/`) skip qc-structural; CI is still required.
- `sh dev/review/pr_gate_status.sh [PR...]` prints each open PR's CI, verdict (ok / rework /
  stale(<sha>) / none / skip) and next step (`merge`, `merge (structural: <reason>)`, or `user review (<reason>)`).
  `sh dev/review/format_only_changes.sh` lists files changed only in formatting; CI prints the same list as warnings.

## User guides

A new or changed program updates its guide. Every registered program has a player's page in
`docs/guide/<program id>.md` (`docs/guide/README.md`): hand-written prose around blocks generated
from the registry and the plans. After changing a program's plans, its descriptor or its commands,
run `cd src && opam exec -- dune exec -- gamepilot guide --write` and reread the prose around the
blocks. CI runs `gamepilot guide --check`, which fails on a missing page, a stale block (any plan
change makes its checkpoints block stale) or a skeleton's unfinished `TODO(guide)`.

## Agents

Harness from `dayfine/agent-harness` (`.agents/agents/`, `.agents/rules/`, `dev/lib/`, `.agents/checks/`).
