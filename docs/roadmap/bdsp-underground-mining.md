# D. BDSP Underground mining

Goal: a program that farms Mysterious Shards in the Grand Underground until the save holds enough
shards for the target Ramanas Park slates, saves, and leaves the Underground. No prior Underground
program exists on the fork; this page records the verified game mechanics, the layered optimization
methodology and live metrics from Console A, and the implemented modules.

## Verified game mechanics

- **Ramanas Park slates (target):** 14 slates total per version unlock all legendaries (fork PR
  #782, `docs/roadmap/bdsp-legendary-rng.md`). Each slate costs either **3× Mysterious Shard S** or
  **1× Mysterious Shard L**, so the stop condition is `shard_L + (shard_S / 3) >= target_slates`
  (14 Large, 42 Small, or any mix). Unlocked after obtaining the National Pokédex.
- **Region & entry point:** All 6 partitioned regions of the Grand Underground share the **same
  global mining item pool** (~2.87% Shard S, ~0.96% Shard L per item slot; 2–4 items per wall).
  Region choice is purely about corridor geometry and convenience: flying to **Oreburgh City**
  (Sinnoh Town Map offset `(10, 14)` from the top-left hold-clamp) and diving via the Explorer Kit
  drops directly into the East corridor of the Central Grassland Cave farming ring, where homing
  (`N -> E -> S -> W`) lands outside the South Hideaway doorway.
- **Ignore the 40-Diglett bonus (`LightStone`):** Datamines confirm the 4-minute 40/40 Diglett
  bonus only boosts Gorgeous Boxes (5% → 95%) and doubles Hideaway shiny odds (1/4096 → 1/2048);
  it does **not** change Mysterious Shard drop rates. Play **offline** (`Play Alone`, row 2 =
  `Down 2` + `A` in the Explorer Kit mode menu) and skip Digletts.
- **Instant dig-spot refresh (verified live on Console A):** Stepping through **any Pokémon
  Hideaway doorway** and immediately walking back out (~4 s total) instantly respawns all sparkling
  dig spots in the surrounding tunnels with zero wild Pokémon encounters.
- **Mining minigame (verified live on Console A):**
  - **13 columns × 10 rows** grid at normalized frame box `x = 0.1328..0.7484`,
    `y = 0.1111..0.9556`.
  - Cursor starts at `(6, 4)` with **Blue Pickaxe** selected; **R** toggles **Red Hammer** (cost 2,
    3×3) ↔ **Blue Pickaxe** (cost 1, 5-tile cross); **A** strikes.
  - **49 wall-integrity points** (crack grows right-to-left across `y = 0.00..0.11`).
  - Post-dig dialog advances with **A**, not **B**.

## Layered optimization methodology & metrics

Because an end-to-end shard run chains six distinct subsystems (overworld transit, doorway refresh,
map routing, radar wall-locking, 13×10 mining, and yield accounting), optimizing top-down hides
root causes: a broken doorway bounce or missed wall-lock looks identical to bad shard RNG in the
final count. We instead isolate, measure, and tune **bottom-up by layer**, validating each layer
offline (unit / synthetic / Monte Carlo tests) and live on Console A before moving up:

| Layer | Subsystem | Primary Metric(s) | Offline Test | Live Verification & Progress |
|---|---|---|---|---|
| **0. Cycle & Transit Reliability** | Startup transit (`Outdoor_transit`), doorway bounce & self-healing (`Underground`), periodic auto-save (`Auto_save`), battle escape | Crashes / stalls per 100 cycles; doorway self-heal recovery rate; auto-save success rate | Unit tests for `Fly` offsets & `in_underground` HUD | Sustained runs (`run-8`..`run-13`): **73 cycles, 160 digs, 0 crashes**, **15/15** doorway drift self-heals, **25/25** auto-saves. Outdoor transit waits on `in_underground` state rather than transient black fade. |
| **1. Map Reading & Route Planning** | Full-map sparkle detection (`Minimap_sparkles`) & ring corridor routing (`Ring_grid`, `Ring_navigator`) | Planned stops per cycle; return-to-doorway accuracy | `test_ring_navigator.ml`, `test_ring_grid.ml` | Plans 3–5 sparkle stops per cycle around the Grassland Cave ring and returns along corridor walls to the South doorway. |
| **2. Stop-to-Dig & Wall-Lock** | Radar `[R]` sparkle blob-diffing (`Wall_sparkle`) & servo approach (`Wall_lock`) | **Dig hit rate** (`digs / stops`); **radar detection rate** (`stars_seen / stops`) | `test_wall_sparkle.ml` (torch rejection, 35 px static cancellation, player exclusion) | Hit rate climbed **10%** (baseline) → **50%** (`run-10`) → **53%** (`run-12`) → **65.7%** (`run-13`: 69/105 stops, **90.5%** radar detection) via `core.find@1` blob-diffing (`RGB 245..255, 240..255, 230..255` rejecting orange torches), calibrated tile speeds (`130 ms` H / `135 ms` V + `110 ms` start), symmetric `±2` lateral search, and return-to-stop after failed reprobes. |
| **3. Mining Minigame Efficiency** | 130-cell wall classifier (`Mining_grid`), solver (`Mining_solver`), and execution loop (`Mining_play`) | Wall cell coverage %; shard extraction rate on 200-wall benchmark; moves & bail rate | `test_mining_grid.ml`, `test_mining_solver.ml` (200-wall Monte Carlo) | Fixed shadowed col-0 dirt, warm-rock dead zones, and `uncovered_ids` inference; added layer-aware exposure-per-integrity scoring, `unwanted_footprint` avoidance, full-wall greedy scan fallback, 800 ms Hammer settle, and exact local integrity tracking. 200-wall benchmark: **Shard L 193/200 (96.5%)**, **Shard S 186/200 (93.0%)**, **Other 200/200**. |
| **4. Yield Classification & Accounting** | Spotlight item classifier (`Dig_result_reader`), rising-edge deduplication (`Mining_play`), slate tally (`Mining_goal`) | False-positive Shard rate; Shard S vs Shard L separation | Unit tests + captured Console A spotlight frames | Rising-edge `in_spot` deduplication eliminated double-counting. Pink thresholds calibrated on live Shard S (`0.0172`), Shard L (`0.0284..0.0310`), Heat Rock (`0.0016`), and Red Sphere (`0.0006`): `RGB (180..255, 0..140, 165..255)`, `shard_l >= 0.024`, `shard_s >= 0.010`. |
| **5. Live Observability** | Protocol v1.21 `watch.counters` (`Wire`, `Effects`, `Watch_report`, daemon journal & Watch UI) | Live counter visibility during unattended runs & post-run history | `ctest` (`14/14`), OCaml `base` & `core` tests | Emits live `Cycles`, `Refreshes`, `Digs (bailed)`, `Shards (S / L)`, `Slates`, `Spheres`, `Stones / Fossils`, `Boxes / Other`, and `Battles` to the Watch Page and run journal. |

### Debugging workflow per layer

1. **Isolate with step modes first:** Use `mode=step-refresh`, `step-read-map`, `step-route-one`,
   and `step-dig-one` to verify a single layer on hardware before running a multi-cycle `farm` run.
2. **Capture frames, not guesses:** Whenever a vision threshold or timing misses on Console A, pull
   the exact frames from the run folder (`wire.jsonl` + saved frames) and measure RGB/area values
   directly before tuning constants.
3. **Lock in regressions with offline tests:** Every threshold or solver fix lands alongside a unit
   test (`test_wall_sparkle.ml`, `test_mining_grid.ml`, `test_mining_solver.ml`,
   `test_ring_navigator.ml`) so later refactors cannot silently erode an earlier layer.

## Implemented modules

- `src/base/wire/`, `src/core/`, `daemon/`, `protocol/v1/`: game-agnostic `watch.counters`
  notification (protocol v1.21), journal persistence, and Watch UI Counters card.
- `src/games/pokemon/bdsp/underground/` (`gamepilot.bdsp_underground`): pure `Mining_goal`,
  `Mining_wall`, `Mining_solver`, `Ring_grid`, `Mining_counters`, and `Corridor_nav` with offline
  unit and Monte Carlo tests.
- `src/games/pokemon/bdsp/readers/` (`gamepilot.bdsp_readers`): `Menu_detector`, `Dialog_detector`,
  `Battle_detector`, `Minimap_sparkles`, `Wall_sparkle` (blob-diff), `Underground_screen`
  (including `in_underground` Diglett HUD detection), `Mining_announce_reader`, `Dig_result_reader`,
  and `Mining_grid` (130-cell live classifier + live wall-crack gauge).
- `src/games/pokemon/bdsp/actions/` (`gamepilot.bdsp_actions`): reusable `Fly` and `Save_game`
  modules, plus `Game_entry`, `Overworld_actions`, and `Mining_play` (`dig_wall_smart`,
  `collect_dig_yields`).
- `src/games/pokemon/bdsp/programs/underground/` (`bdsp.underground`): `Outdoor_transit`,
  `Auto_save`, `Wall_lock`, `Ring_navigator`, `Step_modes`, and the main `Underground` loop
  verified live on Console A via `gamepilot run bdsp.underground --watch`.
