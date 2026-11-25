# Supplies

Stocks the items other programs use up, so they can check a count instead of shopping themselves:
100 Retro Mail from the Celadon Dept. Store 4F (the Mail Glitch's item duplication spends one per
copy) and 5 Super Repels from the Lavender Mart. It starts and ends at the Dept. Store 1F save spot
and costs ¥7,500. The list is fixed for now; a configurable shopping list is planned.

<!-- generated:backends -->
Runs on: mGBA, the Switch.
<!-- /generated -->

## Before you start

<!-- generated:needs -->
- 0 free party slots
- pidgey in the party (fly)
- money at least ¥7500 (all the purchases)
- at the start, CeladonCity_DepartmentStore_1F
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh --program frlg.supplies --from su-01 --to su-01 --mode verification

# the Switch: check the save first, then run (each checkpoint once, saved when it passes)
sh run/run_checkpoints_on_switch.sh --program frlg.supplies --from su-01 --to su-01 --preflight-only
sh run/run_checkpoints_on_switch.sh --program frlg.supplies --from su-01 --to su-01
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| su-01 | Stock 100 Retro Mail (Celadon 4F) and 5 Super Repels (Lavender) |

<!-- plans: 28c66bfb3e93 -->
<!-- /generated -->

## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| su-01 | pidgey in the party (fly); money at least ¥7500 (mart, mart); at the start, CeladonCity_DepartmentStore_1F |
<!-- /generated -->

## Known limits
