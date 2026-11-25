# Supplies

Stocks the items other programs use up, so they can check a count instead of shopping themselves.

It buys a fixed list for now (a configurable shopping list is planned), for ¥7,500:

- 100 Retro Mail from the Celadon Dept. Store 4F: the Mail Glitch's item duplication spends one per
  copy.
- 5 Super Repels from the Lavender Mart.

<!-- generated:backends -->
Runs on: mGBA, the Switch (in its GBA app).
<!-- /generated -->

## Before you start

Save at the Celadon Dept. Store 1F save spot: the run starts and ends there.

<!-- generated:needs -->
- pidgey in the party (fly)
- the thunder badge (fly)
- money at least ¥7500 (all the purchases)
- at the start, CeladonCity_DepartmentStore_1F
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh frlg.supplies --from su-01 --to su-01 --mode verification

# the Switch: check the save first, then run (each checkpoint once, saved when it passes)
sh run/run_checkpoints_on_switch.sh frlg.supplies --from su-01 --to su-01 --preflight-only
sh run/run_checkpoints_on_switch.sh frlg.supplies --from su-01 --to su-01
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| su-01 | Stock 100 Retro Mail (Celadon 4F) and 5 Super Repels (Lavender) |

<!-- plans: 741bdeff32cd -->
<!-- /generated -->

## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| su-01 | pidgey in the party (fly); the thunder badge (fly); money at least ¥7500 (mart, mart); at the start, CeladonCity_DepartmentStore_1F |
<!-- /generated -->

## Known limits
