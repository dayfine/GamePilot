# AutoStory

Plays Pokémon Legends: Z-A's story on the Switch. For now it is the program's frame with one
checkpoint: from the station platform it walks down and right until the white fade into the arrival
scenes (checkpoint 01.01). The story's scenes, battles and catches, and the checkpoints after 01.01,
come later.

<!-- generated:backends -->
Runs on: the Switch.
<!-- /generated -->

## Before you start

Put the console on the station platform by hand, with free control: the controls hint showing and
nothing on screen. The Switch's capture must be the whole 1920x1080 picture (the daemon's
`--viewport native`).

## Running it

<!-- generated:commands -->
```sh
# the Switch: each checkpoint once, from where the console is
cd src && opam exec -- dune exec -- gamepilot run plza.autostory --from 01.01 --to 01.01 --mode testing --backend switch --serial PORT --capture DEVICE \
    --watch
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01.01 | The platform to the plaza |

<!-- plans: d8b3e5bd84ce -->
<!-- /generated -->

01.01 waits for free control, walks down the platform and right, and passes when the screen fades
to white.

## When it stops

- The run starts wherever the console is; nothing reloads, so each checkpoint runs once
  (`--runs 2` is refused).
- A walk whose white fade never shows fails `walk_no_end`.
- The run folder keeps the story log, the wire log and `failure.png`, the last frame of a failed
  run.

## Known limits

- Walks are timed stick legs with no map, so they can miss.
- The daemon keeps the console awake with the right stick (up, then down), not B, which would back
  out of the new game's menus.

## How it works

`Plza_series.Runs` runs each checkpoint in its own daemon and run folder, with the watch page.
`Plza_autostory.Story_game` gives the engine its handlers: today only the walk
(`Plza_walk.Walk`, ported from `PokemonLZA_AutoStoryWalks.cpp`); any other event fails
`no_handler`. `Plza_autostory.Live_story_screen` reads the screen for the walk from PLZA's readers.
