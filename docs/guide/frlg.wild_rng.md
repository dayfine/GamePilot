# Wild RNG

Catches a shiny Ekans in Route 10's grass, on purpose, in about a minute. As PA/CC's RNG programs
do, it restarts the game and presses A on the title screen, then uses Sweet Scent, at moments
worked out for your trainer ID and secret ID, so the wild Pokémon is the one chosen in advance. It
throws Poké Balls and checks the star on the catch's summary before saving.

<!-- generated:backends -->
Runs on: mGBA.
<!-- /generated -->

## Before you start

Your party's last Pokémon must know Sweet Scent (Oddish here), with Sweet Scent second on its menu,
and the game's sound must be Mono with the button mode Help.

The plan holds your trainer ID (TID) and secret ID (SID) as `tid` and `sid` on its `wild_rng`
event. The TID is on your Trainer Card. The game never shows the SID: find it with PA/CC's SID
Helper (Pokémon FRLG, *SID Helper*), which runs on a new game's naming screen and lists the
possible SIDs.

The list shows in the program's *TID/SID Results* box, in its *SID Candidates* notification and
in its log (`Possible SIDs:`). At the PA/CC version GamePilot builds against, the box is not saved
in `SerialPrograms-Settings.json`, so copy the SID from the box or the log.

A Switch FireRed save takes its SID the same way, once, into the plan. The mGBA save these plans
were made on has SID 9011, read from the game's memory.

Each save also needs its seed shift measured (below).

<!-- generated:needs -->
- 1 free party slot (joining: ekans in 02-shiny-ekans)
- a member holds no Mail (pc_deposit)
- a member knows fly (fly)
- the thunder badge (fly)
- poke-ball at least x1 (wild_rng)
- at the start, anywhere outdoors where Fly works
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh frlg.wild_rng --from 01-route10-grass --to 02-shiny-ekans --mode verification
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01-route10-grass | From anywhere outdoors: fly to Route 10, a party slot free in the Center's PC, into the north grass, saved |
| 02-shiny-ekans | Route 10's north grass: a hard reset timed for a shiny Ekans, Sweet Scent, the catch, its summary's star, saved |

<!-- plans: 55dbaca1a59d -->
<!-- /generated -->

## When it stops

<!-- generated:preflight -->
| Resume from | The pre-flight checks |
|---|---|
| 01-route10-grass | a member holds no Mail (pc_deposit); a member knows fly (fly); the thunder badge (fly); at the start, anywhere outdoors where Fly works |
| 02-shiny-ekans | poke-ball at least x1 (wild_rng); at the start, Route10 |
<!-- /generated -->

## Known limits

- mGBA only. The seed table was measured on mGBA from the Sevii story's end save, and 02's
  `seed_shift` from the save 01 makes; a save made another number of saves later can need
  another offset, and misses the target until it is measured.
- If the catch is not shiny, the checkpoint fails before saving and the run tries again from its
  start.
- One species and one place so far: Ekans in Route 10's north grass.

## How it works

A port of the fork's WildRng (PA/CC's `PokemonFRLG/Programs/RngManipulation/`) for Sweet Scent in
grass, so every catch toward the 60 the National Pokédex needs can be shiny (issue #14). The
action is `wild_rng` (`src/games/pokemon/frlg/actions/lib/wild_rng*.ml`).

**The seed.** The seed is the title screen's A press: `backend.reset` (mGBA's power switch) boots
the game from its save, and the press N frames later gives the same seed every time.

**The seed table.** `src/games/pokemon/frlg/assets/rng_seeds_mgba_sevii_save.json` (FR_Eng.json's shape,
delays in ms that round to the press frame) was measured on mGBA from the Sevii story's end save,
the save 01 starts from. The plan names its table (`seeds`).

**The seed shift.** The plan's `seed_shift` is added to every seed. A save's boot ends a few
timer counts later or sooner by where its last save left the flash sectors (the save count modulo
14: 0, 4, 8 or 12 on these saves), which moves every seed by that much. 01's end save adds 8,
measured: the table it gives is the Sevii table plus 8, row for row.

**The in-game offset.** The plan's optional `ingame_offset` (default `0`, in advances) shifts the
Sweet Scent wait, as in the fork's calibration, when the overworld's RNG lands a few advances off
the target (for example on routes with walking NPCs).

**The target.** It is searched, not given: of the table's seeds and advances 900 to 4000, the
shiny Ekans for the plan's TID and SID whose waits add up least (`Frlg_rng.Wild_target`).

**The waits.** They are the C++'s `prepare_timings` with mGBA's frame model
(`Frlg_rng.Rng_timings.mgba`): one advance per frame where the C++ counts two on the Switch, and
Sweet Scent's encounter 183 advances before the formula without its offset.

**The star.** The fork listens for the shiny sound in battle; GamePilot has no audio, so the
Pokémon is caught and its summary read (`Frlg_readers.Shiny_star`). A catch without the star fails
the checkpoint (`wild_rng_not_shiny`) before the save, and the runner retries from the start state.

**Next.** A seed calibration from a miss, as the C++ calibrates, so a save needs no measured
offset, and the Switch's frame model on console. More species, toward the National Pokédex, are
[Dex Collection](frlg.dex_collection.md)'s.
