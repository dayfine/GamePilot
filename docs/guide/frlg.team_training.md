# Team Training

Turns one Rare Candy into 99 with the Mail Glitch's item duplication, for levelling the team.
It needs the glitch active (the end of [Mail Glitch](frlg.mail_glitch.md)), MIMIEN in slot 1 and at
least 99 Retro Mail in the bag (run [Supplies](frlg.supplies.md) first). It flies to Vermilion,
picks up Route 6's hidden Rare Candy under a Super Repel, flies back to the Celadon Dept. Store 1F
and duplicates it. Using the candies is a later checkpoint.

<!-- generated:backends -->
Runs on: mGBA, the Switch (in its GBA app).
<!-- /generated -->

## Before you start

<!-- generated:needs -->
- pidgey in the party (fly)
- mr-mime in the party (give_bag_item)
- the thunder badge (fly)
- super-repel at least x1 (use_item)
- retro-mail at least x99 (duplicate_item)
- at the start, CeladonCity_DepartmentStore_1F
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh --program frlg.team_training --from tt-01 --to tt-01 --mode verification

# the Switch: check the save first, then run (each checkpoint once, saved when it passes)
sh run/run_checkpoints_on_switch.sh --program frlg.team_training --from tt-01 --to tt-01 --preflight-only
sh run/run_checkpoints_on_switch.sh --program frlg.team_training --from tt-01 --to tt-01
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| tt-01 | Rare Candy farm: pick up Route 6's hidden Rare Candy, duplicate it to 99 |

<!-- plans: 02c27f1dbd19 -->
<!-- /generated -->

## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| tt-01 | pidgey in the party (fly); mr-mime in the party (give_bag_item); the thunder badge (fly); super-repel at least x1 (use_item); retro-mail at least x99 (duplicate_item); at the start, CeladonCity_DepartmentStore_1F |
<!-- /generated -->

## Known limits
