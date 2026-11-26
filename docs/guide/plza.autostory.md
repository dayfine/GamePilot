# AutoStory

Plays Pokémon Legends: Z-A's story on the Switch. For now it plays the first two checkpoints: from
the new game's Confirm Choices screen through the opening to the station platform (01.00b), then off
the platform through the arrival scenes to Main Mission 01 (01.01). The checkpoints after 01.01, with
their battles and catches, come later.

<!-- generated:backends -->
Runs on: the Switch.
<!-- /generated -->

## Before you start

Start a new game by hand up to its Confirm Choices screen (language, look and name), for 01.00b; or
put the console on the station platform with free control, the controls hint showing, to run 01.01
alone (`--from 01.01`). The Switch's capture must be the whole 1920x1080 picture (the daemon's
`--viewport native`).

## Running it

<!-- generated:commands -->
```sh
# the Switch: each checkpoint once, from where the console is
cd src && opam exec -- dune exec -- gamepilot run plza.autostory --from 01.00b --to 01.01 --mode testing --backend switch --serial PORT --capture DEVICE \
    --watch
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01.00b | Confirm Choices to the station platform |
| 01.01 | The platform to Main Mission 01 |

<!-- plans: 2e6025478e20 -->
<!-- /generated -->

01.00b confirms the choices, skips the opening and waits for the platform. 01.01 sets the text
speed to fast, walks down the platform and right to the white fade, and presses through the arrival
scenes (Plus skips the president's ad) until the controls hint shows again.

## When it stops

- The run starts wherever the console is; nothing reloads, so each checkpoint runs once
  (`--runs 2` is refused).
- 01.00b on any screen but Confirm Choices presses nothing and fails `not_on_confirm_choices`.
- When the platform's controls hint has faded (it does after a few seconds idle), 01.01 would reload
  the latest autosave to see it fresh; the runner cannot reload yet, so it fails `no_reload`. Start
  01.01 right after 01.00b, or move the stick by hand first.
- A walk whose white fade never shows fails `walk_no_end`.
- The run folder keeps the story log, the wire log and `failure.png`, the last frame of a failed
  run.

## Known limits

- Walks are timed stick legs with no map, so they can miss.
- The daemon keeps the console awake with the right stick (up, then down), not B, which would back
  out of the new game's menus.

## How it works

`Plza_series.Runs` runs each checkpoint in its own daemon and run folder, with the watch page.
`Plza_autostory.Story_game` gives the engine its handlers: the walk (`Plza_walk.Walk`, ported from
`PokemonLZA_AutoStoryWalks.cpp`), the scene machine (`Plza_story.Scene_machine`) and 01.00b's and
01.01's game actions in `Plza_story`, over its `Steps`; any other event fails `no_handler`.
`Plza_autostory.Live_story_screen` reads the screen into a `Plza_story.Look` from PLZA's readers.
