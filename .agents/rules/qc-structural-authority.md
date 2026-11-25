---
harness: project
---

# qc-structural authority — GamePilot

The project rows the qc-structural reviewer (`.agents/agents/qc-structural.md`) appends to its
generic checklist. The agent holds the protocol (checkout, CI as the build of record, the review
format); this file holds what is specific to GamePilot. Each row comes from a call the user made
on a real PR; the PR is named so the reviewer can read the case.

## Project context

- Hard rules: `AGENTS.md`. Layers and boundaries: `docs/design/Layered-Automation-Stack.md`.
- The user's review rules, each with examples and how to find it: `.agents/rules/review-rules.md`.
  The rows below cite them by id.
- Lints: `dev/lint/lint_ocaml.sh` (function length, nesting, magic numbers, file length, `.mli`
  for every `lib/` module, layer boundaries, no exceptions) with waivers in
  `dev/lint/ocaml_lint_exceptions.conf`; `dev/lint/lint_dune.sh` (no C, opam allowlist).
- Tests: every library `<name>/lib` has `<name>/test`. Tests use plain OCaml with the fakes the
  test file defines.

## Rows (append after P4)

```
| # | Check | Status | Notes |
|---|-------|--------|-------|
| S1 | One concern per PR | PASS/FAIL | |
| S2 | No unrelated changes | PASS/FAIL | |
| S3 | Names say what a thing is | PASS/FAIL | |
| S4 | Errors are values; the waiver list only shrinks | PASS/FAIL/NA | |
| S5 | Every new type and val in an .mli has a doc comment a newcomer understands | PASS/FAIL/NA | |
| S6 | Tests are readable | PASS/FAIL/NA | |
| S7 | Reuse and composability | PASS/FLAG/FAIL | |
| S8 | A port names its C++ source and where it differs | PASS/FAIL/NA | |
| S9 | GitHub text hygiene | PASS/FAIL | |
```

### S1 One concern per PR

Read the title and body, then the file list. Every file must serve the concern the title names.
Files that serve a second concern (a new reader under a new action, a shared module under its
first user, a lint under a feature) → **FAIL**, naming those files and the split. A PR that needs
its own parts reviewed first is a stack: each part its own PR, "Depends on #N" at the top.

Case: #26 carried party-menu readers, a shared level-up module and the Rare Candy actions; the
user had it split into #29 (readers), #30 (the shared `Level_up`) and #26 (candy, on top).

### S2 No unrelated changes

Run `sh dev/review/format_only_changes.sh origin/main <tip>` (CI's "Review tools" run prints the
same list as warnings). Every listed file the PR is not about → **FAIL**: formatting-only edits
(JSON that parses to the same value, OCaml or other files reflowed or reindented) and files moved
unchanged. Also read the diff for drive-by renames and edits the script cannot see (a renamed
identifier across unrelated modules, a comment rewritten in a file the PR does not otherwise
touch). A format or rename PR whose title says so is its own concern and passes.

Case: an earlier tip of #25 reformatted all nine Mail Glitch plan JSONs, content identical
(fixed by "Mail Glitch plans: undo an unrelated reformat").

### S3 Names say what a thing is

`AGENTS.md`: no catch-all modules or folders (`helpers`, `utils`, `common`, `misc`). Names
explain themselves without the PR for context: no private jargon (the user questioned `rig` and
`only` in #30). One convention is fixed:

- The record of game reads and actions a deciding module takes is `game_steps`. Builders are
  `<context>_game_steps` (e.g. `candy_game_steps`), test fakes are `fake_game_steps`
  (`src/games/frlg/actions/lib/level_up.mli` is the reference).
- `rig`, `driver`, `handlers`, `ops`, `callbacks` for that record → **FAIL** ("handler" also
  clashes with the effect handlers in `core/`).
- `deps` only for a struct of external resources or connections, never for game steps.

New names leave out "story" for goal programs and engine parts that are not story-specific
(Mail Glitch is a goal program).

### S4 Errors are values

Game code returns `result`; exceptions stay at the effects/I/O boundary (`core/effects`,
`session`, `live`, `replay` and the runners). `lint_ocaml.sh`'s `no_exceptions` check enforces it
through `dev/lint/ocaml_lint_exceptions.conf`, whose `no_exceptions` lines only shrink. A PR that
**adds** a `no_exceptions` line → **FAIL** unless the PR body says why the exception cannot be a
value. Other waivers (`magic_numbers`, `function_length`, ...) are allowed with a reason on the
line (AGENTS.md) and are not this row. NA when no `no_exceptions` line is added; removing them
passes.

### S5 Documented interfaces

Every new or changed `type`, constructor and `val` in an `.mli` has a doc comment that says what it
is for, in words a newcomer to the codebase understands: no unexplained abbreviations, no names of
other private ideas without a pointer to them. Module doc comments say what the module does and,
for a port, where it comes from (S8). Text read from the game screen (dialogue, menu labels)
names its language risk: GamePilot keeps multi-language support as a goal. An undocumented type
or val → **FAIL** naming it. Applies to `lib/` interfaces; a variant whose constructors say it
all (`Mono | Stereo`) still needs one line on what the type is for. The lint `interface_docs`
(R11) finds a missing doc; this row judges what it says, and new items in a file it still waives.

### S6 Readable tests

- One expectation per fact: a long expected string that packs several facts (a whole trace, a
  multi-line log) → **FAIL**; check each fact on its own (#30 review). A golden-vector record
  (one input and its outputs from the C++, printed as one line) is one fact: it passes when a
  mismatch prints that record.
- The test file says what its fakes are and what each one stands in for (a comment at the top or
  at the fake).

### S7 Reuse and composability

Look for new code or plan data that repeats what exists:

- Plan steps repeated across plans (e.g. "walk to the lift, ride to 4F, walk to the clerk" in
  several plans) → named places and `go_to`, not copies (#25 review).
- A new module or function that does what an existing one does → name the existing one.
- A program that hard-codes what a player would choose (a shopping list, a count, a target
  level): programs are configurable, validate their input, and check their preconditions
  (money, items, Fly) before they start (#25 review).
- Tasks built as blocks (catch, train, supply) that plans chain, so other programs reuse them.

These are design questions for the user: **FLAG** with the duplicated places named. **FAIL** only
when code or plan steps are duplicated verbatim (copy-paste of a function or a run of steps).

### S8 Port transparency

`AGENTS.md`: a port of fork C++ keeps its behaviour, steps, order and timings, and each module's
doc comment names the C++ file(s) it comes from. Where it deliberately differs (a missing reader,
a new strategy) the doc comment says so. A ported module without its source named → **FAIL**.
Reshaping a port in the same PR that ports it → S1 FAIL. NA when nothing is ported.

### S9 GitHub text hygiene

The PR title, body and commit messages: no bare `@name` unless it is a real login meant to be
notified. Dune aliases and code (`@fmt`, `@runtest`, `@types/...`) go in backticks: a bare `@fmt`
pinged a real GitHub user. No machine paths or personal details (the repo is public; `AGENTS.md`
on `GAMEPILOT_*` variables and the ROM). → **FAIL** naming the text.

## What the generic agent does not know

- GamePilot's lints and their waiver file (above).
- That docs-only PRs (every file `.md` or under `docs/`) skip this gate; CI is still required.
  A PR that changes dev tools (`dev/`, `.agents/`, workflows) is not docs-only and gets every row.
- That the user spot checks structural changes: an APPROVED structural PR merges, the main session
  holds one now and then for the user, and design docs wait for the user's review. This gate's
  FLAGs go to the main session, which answers them or brings them to the user.
