# Team Training

Turns one Rare Candy into 99 with the Mail Glitch's item duplication, for levelling the team.

From anywhere outdoors, it flies to Vermilion, picks up Route 6's hidden Rare Candy under a Super
Repel, flies back to the Celadon Dept. Store 1F, duplicates it and steps out of the west door. Using
the candies is a later checkpoint.

<!-- generated:backends -->
Runs on: mGBA, the Switch (in its GBA app).
<!-- /generated -->

## Before you start

- The glitch active: the end of [Mail Glitch](frlg.mail_glitch.md).
- MIMIEN in slot 1.
- At least 99 Retro Mail in the bag: run [Supplies](frlg.supplies.md) first.

<!-- generated:needs -->
- mr-mime in the party (give_bag_item)
- a member knows fly (fly)
- the thunder badge (fly)
- super-repel at least x1 (use_item)
- retro-mail at least x99 (duplicate_item)
- at the start, anywhere outdoors where Fly works
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh frlg.team_training --from tt-01 --to tt-01 --mode verification

# the Switch: check the save first, then run (each checkpoint once, saved when it passes)
sh run/run_checkpoints_on_switch.sh frlg.team_training --from tt-01 --to tt-01 --preflight-only
sh run/run_checkpoints_on_switch.sh frlg.team_training --from tt-01 --to tt-01
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| tt-01 | Rare Candy farm: pick up Route 6's hidden Rare Candy, duplicate it to 99 |

<!-- plans: 8af1f31494de -->
<!-- /generated -->

## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| tt-01 | mr-mime in the party (give_bag_item); a member knows fly (fly); the thunder badge (fly); super-repel at least x1 (use_item); retro-mail at least x99 (duplicate_item); at the start, anywhere outdoors where Fly works |
<!-- /generated -->

## Known limits

- It makes the candies but does not use them yet.

## How it works

It turns the Mail Glitch's item duplication into levels (roadmap A1, issue #10). It needs a save
where `frlg.mail_glitch` has run to 08-activate-and-verify: MIMIEN in slot 1 with the glitched mail
record, mail on slots 2 to 6. tt-01 picks up Route 6's hidden Rare Candy under a Super Repel, gives
it to MIMIEN and runs 98 rounds of `duplicate_item`
([Item duplication](frlg.mail_glitch.item_duplication.md)): 99 candies.

**Next.** The levelling checkpoints, once the `candy_level` action lands: Blastoise to Lv 100 as the
lead, then the Dex Collection's catchers (Parasect with Spore, Haunter with Mean Look and Hypnosis).
