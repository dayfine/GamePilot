# Team Training

Turns one Rare Candy into up to 100 (default 99: 1 held + 98 duplicated) with the Mail Glitch's
item duplication, for levelling the team.

From anywhere outdoors, it flies to Vermilion, picks up Route 6's hidden Rare Candy under a Super
Repel, flies back to the Celadon Dept. Store 1F, duplicates it (`--options candies=N`, default 98)
and steps out of the west door. Using the candies is a later checkpoint.

<!-- generated:backends -->
Runs on: mGBA, the Switch (in its GBA app).
<!-- /generated -->

## Before you start

- The glitch active: the end of [Mail Glitch](frlg.mail_glitch.md).
- The glitched-mail holder (e.g. MIMIEN) in slot 1, with mail on slots 2 to 6.
- At least `candies + 1` Retro Mail in the bag (99 for the default 98): run
  [Supplies](frlg.supplies.md) first.

<!-- generated:needs -->
- a member knows fly (fly)
- the thunder badge (fly)
- super-repel at least x1 (use_item)
- retro-mail at least x99 (duplicate_item)
- at the start, anywhere outdoors where Fly works
<!-- /generated -->

## Running it

<!-- generated:options -->
Give each as `--options KEY=VALUE`:

| Key | Values | When not given | What it chooses |
|---|---|---|---|
| `candies` | 1 to 99 | default `98` | how many Rare Candies to duplicate into the bag |
<!-- /generated -->

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

<!-- plans: 2ed821e35d0f -->
<!-- /generated -->

## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| tt-01 | a member knows fly (fly); the thunder badge (fly); super-repel at least x1 (use_item); retro-mail at least x99 (duplicate_item); at the start, anywhere outdoors where Fly works |
<!-- /generated -->

## Known limits

- It makes the candies but does not use them yet.
- Pre-flight checks the default 99 Retro Mail even when `--options candies=N` asks for fewer.

## How it works

It turns the Mail Glitch's item duplication into levels (roadmap A1, issue #10). It needs a save
where `frlg.mail_glitch` has run to 08-activate-and-verify: the glitched-mail holder (e.g. MIMIEN)
in slot 1, mail on slots 2 to 6. tt-01 picks up Route 6's hidden Rare Candy under a Super Repel,
gives it to slot 1 and runs `--options candies=N` rounds (default 98) of `duplicate_item`
([Item duplication](frlg.mail_glitch.item_duplication.md)): 99 candies by default.

**Next.** The levelling checkpoints, once the `candy_level` action lands: Blastoise to Lv 100 as the
lead, then the Dex Collection's catchers (Parasect with Spore, Haunter with Mean Look and Hypnosis).
