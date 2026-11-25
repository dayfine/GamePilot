# Wild RNG

Catches a shiny Ekans in Route 10's grass, on purpose, in about a minute. It uses the same trick
as PA/CC's RNG programs: the game picks its random numbers from the moment you press A on the title
screen, so pressing at the right moment, then using Sweet Scent at the right moment, brings out a
wild Pokémon chosen in advance. The program works out which moment gives a shiny Ekans for your
trainer ID and secret ID, restarts the game, presses for you, throws Poké Balls, and checks the
star on the catch's summary before saving.

<!-- generated:backends -->
Runs on: mGBA.
<!-- /generated -->

## Before you start

Your party's last Pokémon must know Sweet Scent (Oddish here), with Sweet Scent second on its menu,
and the game's sound must be Mono with the button mode Help.

The plan holds your trainer ID (TID) and secret ID (SID) as `tid` and `sid` on its `wild_rng`
event. The TID is on your Trainer Card. The game never shows the SID: find it with PA/CC's SID
Helper (Pokémon FRLG, *SID Helper*), which runs on a new game's naming screen and lists the
possible SIDs. The list shows in the program's *TID/SID Results* box, in its *SID Candidates*
notification and in its log (`Possible SIDs:`). PA/CC keeps each program's settings in
`SerialPrograms-Settings.json` (its `UserSettings` folder, under `99-Panels`, then
`PokemonFRLG:SidHelper`), but at the PA/CC version GamePilot builds against the result box is
display-only and is not written there, so copy the SID from the box or the log. A Switch
FireRed save takes its SID the same way, once, into the plan. The mGBA save these plans were made
on has SID 9011, read from the game's memory.

Each save also needs its own seed table (below).

<!-- generated:needs -->
- 1 free party slot (joining: ekans in 02-shiny-ekans)
- pidgey in the party (fly)
- mr-mime in the party (pc_deposit)
- poke-ball at least x1 (wild_rng)
- at the start, CinnabarIsland
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh --program frlg.wild_rng --from 01-route10-grass --to 02-shiny-ekans --mode verification
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01-route10-grass | From Cinnabar: fly to Route 10, a party slot free in the Center's PC, into the north grass, saved |
| 02-shiny-ekans | Route 10's north grass: a hard reset timed for a shiny Ekans, Sweet Scent, the catch, its summary's star, saved |

<!-- plans: 413778a9820e -->
<!-- /generated -->

## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| 01-route10-grass | pidgey in the party (fly); mr-mime in the party (pc_deposit); at the start, CinnabarIsland |
| 02-shiny-ekans | poke-ball at least x1 (wild_rng); at the start, Route10 |
<!-- /generated -->

## Known limits

- mGBA only. The seeds were measured on mGBA from the save 01 makes; another save shifts them a
  little and misses the target, so it needs its seed table measured again.
- If the catch is not shiny, the checkpoint fails before saving and the run tries again from its
  start.
- One species and one place so far: Ekans in Route 10's north grass.
