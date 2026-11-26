# D. BDSP Underground mining

Goal: a program that digs in the Grand Underground until the save holds enough Mysterious Shards
for the target Ramanas Park slates, then stops. No prior Underground program exists on the fork;
this page records the verified game mechanics, live Console A measurements, and implemented
modules.

## Verified game mechanics

- **Ramanas Park slates (target):** 14 slates total per version unlock all legendaries (fork PR
  #782, `docs/roadmap/bdsp-legendary-rng.md`). Each slate costs either **3× Mysterious Shard S** or
  **1× Mysterious Shard L**, so the stop condition is `shard_L + (shard_S / 3) >= target_slates`
  (14 Large, 42 Small, or any mix). Unlocked after obtaining the National Pokédex.
- **Region choice:** All 6 partitioned regions of the Grand Underground share the **same global
  mining item pool** (~2.87% Shard S, ~0.96% Shard L per item slot; 2–4 items per wall). Region
  choice is purely about corridor geometry and convenience: dive from **Route 221 (Ramanas Park)**
  or any outdoor spot into a corridor directly adjacent to a Pokémon Hideaway doorway.
- **Ignore the 40-Diglett bonus (`LightStone`):** Datamines confirm the 4-minute 40/40 Diglett
  bonus only boosts Gorgeous Boxes (5% → 95%) and doubles Hideaway shiny odds (1/4096 → 1/2048);
  it does **not** change Mysterious Shard drop rates. Play **offline** (`一人遊玩`, row 2 = `Down 2`
  + `A` in the Explorer Kit mode menu) and skip Digletts.
- **Instant dig-spot refresh (verified live on Console A):** Stepping through **any Pokémon
  Hideaway doorway** and immediately walking back out (~4 s total) instantly respawns all sparkling
  dig spots in the surrounding tunnels with zero wild Pokémon encounters.
- **Mining minigame (verified live on Console A):**
  - **13 columns × 10 rows** grid at normalized frame box `x = 0.1328..0.7484`,
    `y = 0.1111..0.9556`.
  - Cursor starts at `(6, 4)` with **Blue Pickaxe** selected; **R** toggles **Red Hammer** (cost 2,
    3×3) ↔ **Blue Pickaxe** (cost 1, 5-tile cross); **A** strikes.
  - **49 wall-integrity points** (crack grows right-to-left across `y = 0.00..0.11`).
  - Post-dig dialog (`牆壁崩塌了！`) advances with **A**, not **B**.

## Self-aligning corridor navigation

A one-shot program `bdsp.underground_poc` in `src/games/pokemon/bdsp/programs/`, Switch backend only.
BDSP overworld timings come from fork PR #402 (`BDSP_MOVE_MECHANICS`), calibrated live on Console A:

1. Bounce through the Hideaway doorway (`West` → `East`, with perpendicular 350 ms auto-centering
   nudge if off-center) to refresh dig spots.
2. Hug the North wall and sweep East toward the South-East corner, digging any sparkle.
3. Self-align against the East wall and sweep North, digging any sparkle.
4. Return South to the South-East corner wall and West back to the Hideaway doorway.

## Implemented modules

- `src/games/pokemon/bdsp/underground/` (`gamepilot.bdsp_underground`): pure `Mining_goal`, `Mining_wall`,
  `Mining_solver`, `Ring_grid`, `Mining_counters`, and `Corridor_nav` with offline unit & Monte Carlo tests.
- `src/games/pokemon/bdsp/readers/` (`gamepilot.bdsp_readers`): `Menu_detector`, `Dialog_detector`,
  `Battle_detector`, `Minimap_sparkles`, `Wall_sparkle`, `Underground_screen`, `Mining_announce_reader`,
  `Dig_result_reader`, and `Mining_grid` (130-cell live classifier + live wall-crack gauge).
- `src/games/pokemon/bdsp/actions/` (`gamepilot.bdsp_actions`): `Bdsp_game_entry`, `Bdsp_overworld`, and
  `Bdsp_mining_play` (`dig_wall_smart`, `collect_dig_yields`).
- `src/games/pokemon/bdsp/programs/underground_poc/` (`bdsp.underground_poc`): registered Switch one-shot
  program verified live on Console A via `gamepilot run bdsp.underground_poc --watch`.
