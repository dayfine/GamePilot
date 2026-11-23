# Roadmap: Start menu PoC to the Mail Glitch on console B (2026-11-23)

The goal is the Mail Glitch (`mg-01`..`mg-05`, fork #781) written as an OCaml program: first on mGBA
(S0), then on console B's post-game save (S1). Decisions live in `docs/design/Layered-Automation-Stack.md`
section 13 (R1-R20). This file says what is built in what order. Mark each item done with its PR.

## Phase 0: foundation (now)

| Item | Where | Done when |
|---|---|---|
| Layout and naming (R16, R17) | `src/` | #5 merged |
| PokemonSimulation submodule, `mg-*` plans copied (R18) | `third_party/`, `games/frlg/programs/mail_glitch/plans/` | #6 merged |
| **OCaml linters** (see below) | `lint/` | run in `dune test` and CI before any large port lands |
| Contract v1.1: load counter in `frame`, method in responses, probe kind in results; replay checks every recorded request was sent | `contracts/`, `daemon/`, `src/base/wire`, `src/core/replay` | both sides pass the golden files; PoC passes live again |

### Linters

Port the generic linters from `dayfine/trading` (`trading/devtools`) before the grid port, so the
ported code is written to them instead of fixed afterwards:

- function length, nesting depth, magic numbers, cyclomatic complexity (advisory), file length,
  `.mli` coverage for every `lib/` module (OCaml, `compiler-libs`);
- layer boundaries from the layout: `base` depends on nothing of ours, `core` on `base`, `pokemon` on
  `core` and `base`, a game on `pokemon`, `core` and `base`, a program on its own game; `bin` on anything;
- one exceptions file with a reason per entry.

They go in `lint/` as their own dune project, driven by a config file (roots, thresholds, layer
table), with nothing GamePilot-specific in the code. Moving them to a shared repo (for example
`dayfine/ocaml-lint`, used by trading too) is then a `git subtree split` with no code change; that
happens when trading agrees to consume it.

## Phase 1: navigation (pure, no emulator)

Port `Pokemon/Navigation/Grid` from the fork (~6k lines, ~5k of tests) together with its tests.

| Item | Where | C++ source |
|---|---|---|
| Map model: grid, direction, gates, connected maps, move mechanics; loads PokemonSimulation maps | `src/pokemon/navigation/grid/maps` | `Grid/Maps` |
| Leg planner, route scorer, wall and wander recovery | `src/pokemon/navigation/grid/planning` | `Grid/Planning` |
| Leg trace and route log (what was walked vs planned) | `src/pokemon/navigation/grid/trace` | `Grid/Trace` |
| Leg walker (holds as `race` batches, interrupts cleared on the way) | `src/pokemon/navigation/grid/walker` | `Grid/Walker` |

Tests compare against the C++ tests' expectations case by case.

## Phase 2: seeing the screen

| Item | Where |
|---|---|
| Daemon probes: template match (templates uploaded at registration, R13); black screen is `core.color_stats@1` plus a reader threshold (#15) | `daemon/`, `src/base/wire` |
| Screen state: fade, settled, free control (one rule for scenes, as in the fork) | `src/core/screen_state` |
| FRLG readers: dialog, Start menu, bag and item list, party and held item, summary moves, digits, battle screen | `src/games/frlg/readers` |
| R19 decided: font templates for FRLG (no OCR) | design doc |

Each reader gets frames from recorded mGBA wire logs as tests.

## Phase 3: acting

Follow fork #804's split (R20), not #781's monolith.

| Item | Where |
|---|---|
| Overworld and menu actions: talk, Fly, mart, `use_item`, `give_bag_item`, `party_swap`, `buy_coins`, `redeem_prize_mon`, `ingame_trade`, `spin_for_encounter` | `src/games/frlg/actions` |
| Battle driver (single and double, ally targeting, switch, move-learn prompt) and scripted battle runner | `src/games/frlg/battle` |
| Story engine: plan decoder (`pokesim-authored-checkpoint/1`), event runner, `repeat_until` (looped checkpoints that heal and save each round) | `src/pokemon/story` |

## Phase 4: the Mail Glitch on mGBA (S0)

One PR per checkpoint, each with its recorded wire log as a replay test and an mGBA save state at
its start (`~/FRLGLab/mgba/emu-1/saves`, `mail-glitch-test/`).

| Checkpoint | Content |
|---|---|
| mg-01 | Celadon: Coin Case, Retro Mail, 200 coins, Abra |
| mg-02 | Spearow on Route 16, Sitrus Berry on Route 6, trade for CH'DING |
| mg-03 | Abra for MIMIEN on Route 2, Revives at Lavender |
| mg-04 | Level CH'DING to 21 (Knock Off) and MIMIEN to 33 (Recycle) with clean EVs: see below |
| mg-05 | Route 8 setup and the double battle (mGBA only, R9) |

### mg-04: grinding options

The plan grinds wild Gastly, Haunter and Cubone in Pokemon Tower, because they give no HP, Attack or
Speed EVs. It works but is slow (300 encounters for MIMIEN). The checkpoint becomes one `grind` action
with a goal (species, target level, move to learn, EV stats that must stay zero) and several
strategies. The program picks the fastest one the save allows, read from the screen and the plan's
facts (badges, post-game, VS Seeker in the bag):

1. **Tower wilds** (today's plan): always available at this point in the story.
2. **Post-game wilds**: Victory Road or Cerulean Cave, much more experience per battle; flee from every
   species whose EV yield breaks the goal.
3. **VS Seeker rematches**: trainers whose whole party yields only allowed EVs, including double
   battles for two shares of experience per fight; trainer parties from pokefirered.

Strategies and their experience per hour are compared in PokemonSimulation first (policy is
simulated before it is coded), and the plan names the default. The EV table and trainer parties come
from the decomp data, never typed by hand.

## Phase 5: console B (S1)

| Item | Gate |
|---|---|
| Daemon Switch backend: capture card frames and serial controller (one boundary each, R11) | latency spike: frame to command p99 under one frame (stop rule) |
| mg-01..mg-04 on the post-game save, in console B windows under the one-train rule | 10 runs per checkpoint, pass rate at least the C++ twin's (R9) |

mg-05 stays on mGBA only.

## Standing gates

- Stop rule 4 (dev loop): a reader or action change is checked on recorded runs in seconds, with no
  emulator and no C++ rebuild. If that stops being true, fix that first.
- Every live failure becomes a replay test before the fix.
- No patch on `gamepilot/base` and no new opam dependency without the user.
