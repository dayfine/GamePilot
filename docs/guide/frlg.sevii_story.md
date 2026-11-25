# Sevii Story

Plays the Sevii Islands story on a save that has beaten the Elite Four. So far it does the first
trip. It flies to Cinnabar Island and answers YES to Bill in the Pokemon Center, who takes you to
One Island on the Seagallop. There Celio gives you the Tri-Pass, which the Vermilion ferry needs.
Your save must have turned Bill down when he asked after the Cinnabar Gym, so that he still waits in
the Center. It starts at the Celadon Dept. Store 1F save spot, where Supplies and Team Training
end.

<!-- generated:backends -->
Runs on: mGBA.
<!-- /generated -->

## Before you start

<!-- generated:needs -->
- 0 free party slots
- at least 8 badges
- the Hall of Fame entered
- pidgey in the party (fly)
- at the start, CeladonCity_DepartmentStore_1F
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh --program frlg.sevii_story --from 01-to-one-island --to 01-to-one-island --mode verification
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01-to-one-island | Fly to Cinnabar; Bill takes the Seagallop to One Island, Celio gives the Tri-Pass |

<!-- plans: 11d20789c82a -->
<!-- /generated -->

## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| 01-to-one-island | at least 8 badges; the Hall of Fame entered; pidgey in the party (fly); at the start, CeladonCity_DepartmentStore_1F |
<!-- /generated -->

## Known limits

- Once Celio has given you the Tri-Pass, Bill's PC storage stays off until you reach Three Island's
  port. That is the game's own rule, so a program that uses the PC can't run in between.
