# Catcher Prep

Prepares a Spore Parasect sleeper for wild shiny hunts and [Dex Collection](dex_collection.md).
The False Swipe partner comes from Celadon Game Corner's Scyther (`09-shiny-scyther`), which
arrives at Lv 25 already knowing False Swipe (learned at Lv 16 in Gen 3 FireRed).

<!-- generated:backends -->
Runs on: mGBA, the Switch (in its GBA app).
<!-- /generated -->

## Before you start

- Stock enough Rare Candies in the bag with [Team Training](team_training.md) before running
  the leveling checkpoint (roughly 20 to 25 candies cover a freshly caught Lv 5 to 10 Paras to
  Lv 27; more if you also want to level Parasect and Scyther higher afterward).
- Bring Ultra Balls for the wild catch and keep at least one free party slot.

<!-- generated:needs -->
- 1 free party slot (joining: paras in 01-catch-paras)
- a member knows fly (fly)
- the thunder badge (fly)
- ultra-ball at least x10 (capture)
- rare-candy at least x1 (candy_level)
- at the start, anywhere outdoors where Fly works
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh frlg.catcher_prep --from 01-catch-paras --to 02-train-catchers --mode verification

# the Switch: check the save first, then run (each checkpoint once, saved when it passes)
sh run/run_checkpoints_on_switch.sh frlg.catcher_prep --from 01-catch-paras --to 02-train-catchers --preflight-only
sh run/run_checkpoints_on_switch.sh frlg.catcher_prep --from 01-catch-paras --to 02-train-catchers
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01-catch-paras | From anywhere outdoors: catch a Paras in Mt. Moon B1F, save, heal at Route 4 Center, outdoors |
| 02-train-catchers | Level Paras into Spore Parasect (Lv 27) with Rare Candies |

<!-- plans: 1a864dc3297a -->
<!-- /generated -->

## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| 01-catch-paras | a member knows fly (fly); the thunder badge (fly); ultra-ball at least x10 (capture); at the start, anywhere outdoors where Fly works |
| 02-train-catchers | party includes paras; paras in the party (candy_level); rare-candy at least x1 (candy_level); at the start, Route4 |
<!-- /generated -->

## Known limits

- `02-train-catchers` stops at Lv 27 (Parasect's Gen 3 Spore level). Feed extra Rare Candies from
  [Team Training](team_training.md) if you want Parasect and Scyther at Lv 70 to 100 to
  outspeed and tank higher-level wild encounters.
- `02-train-catchers` teaches Spore over `scratch` on Parasect. If Paras no longer knows `scratch`,
  `candy_level` declines the new move and fails its `expect_moves` check.
- Pre-flight checks that the bag has at least 1 Rare Candy (one for the `candy_level` event), not
  the full count required from Paras's current level.

## How it works

Implements Phase 1 catcher preparation from `docs/design/FRLG-Dex-Collection.md`:

- **Mt. Moon B1F (100% Paras)**: Every wild encounter slot on Mt. Moon B1F in FireRed is Paras
  (Lv 5 to 10), so `01-catch-paras` walks straight down the east ladder from Mt. Moon 1F, catches a
  Paras with an Ultra Ball, saves, and returns to Route 4's Pokemon Center to heal.
- **Rare Candy leveling**: `02-train-catchers` uses `candy_level` to evolve Paras into Parasect at
  Lv 24 and teach Spore at Lv 27. Celadon Game Corner Scyther (redeemed in `09-shiny-scyther`)
  arrives at Lv 25 already knowing False Swipe, so no second leveling step is needed here.

### Party order for `frlg.dex_collection`

Arrange your party in this order before starting [Dex Collection](dex_collection.md) with the
Phase 1 catching pair:

1. **Slot 1 — Sleeper**: Spore Parasect.
2. **Slot 2 — False Swiper**: False Swipe Scyther (from `09-shiny-scyther`).
3. **Slot 3 — Fly user**.
4. **Slot 4 — Surf user**.
5. **Slot 5 — Sweet Scent user** (must be the last occupied party slot for `wild_rng`).
6. **Slot 6 — Empty** (receives each caught shiny so the Summary shiny-star check runs on slot 6
   before saving and depositing).
