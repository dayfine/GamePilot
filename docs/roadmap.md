# Roadmap: Start menu PoC to the Mail Glitch on the Switch (2026-11-23)

The goal is the Mail Glitch (`mg-01`..`mg-05`, fork #781) written as an OCaml program: first on mGBA
(S0), then on a Switch's post-game save (S1). Decisions live in `docs/design/Layered-Automation-Stack.md`
section 13 (R1-R20). This file says what is built in what order. Mark each item done with its PR.

## Phase 0: foundation (now)

| Item | Where | Done when |
|---|---|---|
| Layout and naming (R16, R17) | `src/` | #5 merged |
| PokemonSimulation submodule, `mg-*` plans copied (R18) | `third_party/`, `games/frlg/programs/mail_glitch/plans/` | #6 merged |
| **OCaml linters** (see below) | `dev/lint/` | run in `dune test` and CI before any large port lands |
| Contract v1.1: load counter in `frame`, method in responses, probe kind in results; replay checks every recorded request was sent | `protocol/`, `daemon/`, `src/base/wire`, `src/core/replay` | both sides pass the golden files; PoC passes live again |

### Linters

Port the generic linters from `dayfine/trading` (`trading/devtools`) before the grid port, so the
ported code is written to them instead of fixed afterwards:

- function length, nesting depth, magic numbers, cyclomatic complexity (advisory), file length,
  `.mli` coverage for every `lib/` module (OCaml, `compiler-libs`);
- layer boundaries from the layout: `base` depends on nothing of ours, `core` on `base`, `pokemon` on
  `core` and `base`, a game on `pokemon`, `core` and `base`, a program on its own game; `bin` on anything;
- one exceptions file with a reason per entry.

They go in `dev/lint/` as their own dune project, driven by a config file (roots, thresholds, layer
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
| Overworld and menu actions: talk, Fly, mart, `use_item`, `give_bag_item`, `party_swap`, `buy_coins`, `redeem_prize_mon`, `ingame_trade`, `spin_for_encounter`, `cut_tree`; heal and save; `gamepilot checkpoint` (`frlg/shared-actions`; still to come: `lift_floor`, `capture`, berries from the Berry Pouch, a party species reader in place of the reckoned party, live recordings of each flow) | `src/games/frlg/actions`, `src/games/frlg/story` |
| Battle driver (single and double, ally targeting, switch, move-learn prompt) and scripted battle runner (#28; YES/NO and out-of-PP readers, double party list and replay tests still to come) | `src/games/frlg/battle` |
| Story engine: plan decoder (`pokesim-authored-checkpoint/1`), event runner, `repeat_until` (looped checkpoints that heal and save each round) | `src/pokemon/story` |

## Phase 4: the Mail Glitch on mGBA (S0)

One PR per checkpoint, each with its recorded wire log as a replay test and an mGBA save state at
its start (under `GAMEPILOT_STATES`; the source saves are in `mail-glitch-test/`).

| Checkpoint | Content |
|---|---|
| mg-01 | Celadon: Coin Case, Retro Mail, 200 coins, Abra |
| mg-02 | Spearow on Route 16, Sitrus Berry on Route 6, trade for CH'DING |
| mg-03 | Abra for MIMIEN on Route 2, Revives at Lavender |
| mg-04 | Level CH'DING to 21 (Knock Off) and MIMIEN to 33 (Recycle): see below |
| mg-05 | Ported from the fork's tested Route 16 version, in two checkpoints like the fork's: `mg-05a` (Leppa Berry from Route 8, Blastoise's Blizzard PP used up, Fly to Celadon, Route 16's tree, party and held items arranged at (30, 7)) and `mg-05` (Lea & Jed's double battle: Knock Off, Recycle; MIMIEN Lv 33 ends holding the recycled Leppa Berry). Runs on mGBA, then on the Switch (user, 2026-11-23). Still missing: giving a Berry (the Berry Pouch) and `verify_mail_glitch` (a held-item reader) |

### mg-04: grinding options

EVs do not matter (user, 2026-11-23), and the save is post-game with the Sevii Islands not done
(Cerulean Cave and Sevault Canyon closed) and no Exp. Share. PokemonSimulation PR #119
(`docs/progression/mail-glitch-grind.md`) compared the options on the mg-03 party: CH'DING is Lv 22
with Knock Off already, so only MIMIEN (Lv 9 to 33, 35,208 EXP) grinds.

The checkpoint is one `grind` game action per grinder: a goal (species, target level, move to learn,
the move slot it replaces) and a named strategy from `src/games/frlg/assets/grind_strategies.json`
(the spot, who leads, how and how often to heal). The action reads the grinder's moves on the summary
first and passes at once when it knows the move (CH'DING), and ends after the battle the move is
learned in; every other move offered is declined.

1. **Victory Road 2F, switch trick** (default): 40,600 EXP/h, 77 battles, 11 heal trips walked to the
   Indigo Plateau nurse, about 53 min.
2. **Pokemon Tower 5F** (fallback): the switch trick with the PurifiedZone pad. The sim's faster Tower
   row (MIMIEN alone when it outspeeds and surely one-hits, else switch) needs a foe species reader
   and a level reader first.

Missing readers: the grinder's level (the summary draws it in the small font), HP and PP (heals go
by battle count, the sim's rate), and the foe's species.

## Phase 5: the Switch (S1)

| Item | Gate |
|---|---|
| Daemon Switch backend: capture card frames and serial controller (one boundary each, R11) | latency spike: frame to command p99 under one frame (stop rule) |
| mg-01..mg-05 on the post-game save, in Switch windows (only one program drives the console at a time) | 10 runs per checkpoint, pass rate at least the C++ twin's (R9) |

mg-05 runs on the Switch too, after mGBA (user, 2026-11-23; it was mGBA only before).

## Standing gates

- Stop rule 4 (dev loop): a reader or action change is checked on recorded runs in seconds, with no
  emulator and no C++ rebuild. If that stops being true, fix that first.
- Every live failure becomes a replay test before the fix.
- No patch on `gamepilot/base` and no new opam dependency without the user.

## After the Mail Glitch

The plans that follow S0/S1 have one page each under [`docs/roadmap/`](roadmap/README.md) and one
GitHub issue each:

- FRLG after the Elite Four ([parent page](roadmap/frlg-post-e4.md)): [Rare Candies and leveling](roadmap/frlg-rare-candy-leveling.md),
  [Sevii Islands](roadmap/frlg-sevii-islands.md), [ACE balls](roadmap/frlg-ace-balls.md),
  [legendaries](roadmap/frlg-legendaries.md), [Wild and Static RNG port](roadmap/frlg-rng-port.md),
  [dex collection, FireRed exclusives first](roadmap/frlg-dex-exclusives.md).
- [SwSh: story to the DLC](roadmap/swsh-dlc-access.md).
- [BDSP legendary RNG](roadmap/bdsp-legendary-rng.md) and [BDSP Underground mining](roadmap/bdsp-underground-mining.md).
- [SV isolated shiny hunts](roadmap/sv-isolated-shiny.md) and [SV Snacksworth legendaries](roadmap/sv-snacksworth-legendaries.md).
- [PLZA story port](roadmap/plza-autostory-port.md).
