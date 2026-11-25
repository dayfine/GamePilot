# AutoStory

Plays Pokémon Legends: Z-A's story on the Switch from a new game: it confirms the new game's
choices, skips the opening to the station platform, then walks off the platform and presses through
the arrival scenes to Main Mission 01, where you have free control in Lumiose City.

<!-- generated:backends -->
Runs on: the Switch.
<!-- /generated -->

## Before you start

Start a new game by hand: choose the language, the look and the name, and stop on the "Confirm
Choices" screen. Nothing else is read from the save. The Switch's capture must be the whole
1920x1080 picture (the daemon's `--viewport native`).

## Running it

<!-- generated:commands -->
```sh
# the Switch: each checkpoint once, from where the console is
cd src && opam exec -- dune exec -- gamepilot checkpoints --program plza.autostory --from 01.00b --to 01.01 --mode testing --backend switch --serial PORT --capture DEVICE \
    --watch
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01.00b | Confirm Choices to the station platform |
| 01.01 | The platform to Main Mission 01 |

<!-- plans: c3873cd7bd12 -->
<!-- /generated -->

## When it stops

The first run starts wherever the console is. A later run of 01.01 first closes the game and
starts it again from HOME's first tile to load the platform's autosave; 01.00b cannot be reloaded,
so after it fails, put the console back on Confirm Choices by hand and run it again. Each run
keeps its log, wire log and a `failure.png` in its run folder.

## Known limits

Only 01.00b and 01.01 so far. The name and language on Confirm Choices are not checked, and a
title screen asking about the backup save or showing a dialog stops the reload.
