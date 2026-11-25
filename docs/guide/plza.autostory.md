# AutoStory

Plays Pokémon Legends: Z-A's story on the Switch from a new game: it confirms the new game's
choices, skips the opening to the station platform, then walks off the platform and presses through
the arrival scenes to Main Mission 01, where you have free control in Lumiose City. From there it
chases Pancham, answers "Battle with Pokémon!" and stops in the battle area before Ryon.

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
cd src && opam exec -- dune exec -- gamepilot checkpoints --program plza.autostory --from 01.00b --to 01.02 --mode testing --backend switch --serial PORT --capture DEVICE \
    --watch
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01.00b | Confirm Choices to the station platform |
| 01.01 | The platform to Main Mission 01 |
| 01.02 | Main Mission 01: chase Pancham to the battle area |

<!-- plans: 8a46773e27fb -->
<!-- /generated -->

## When it stops

The first run starts wherever the console is. If 01.01 does not see the platform's controls hint,
which fades after a few seconds idle, it reloads the platform's autosave and looks again. A later run of 01.01 first closes the game and
starts it again from HOME's first tile to load the latest autosave (the platform's for 01.01,
Main Mission 01's in Vert District for 01.02); 01.00b cannot be reloaded,
so after it fails, put the console back on Confirm Choices by hand and run it again. Each run
keeps its log, wire log and a `failure.png` in its run folder.

## Known limits

Only 01.00b to 01.02 so far. 01.02's chase is timed stick legs with no map, so it can miss the
scene; the scene then stops on Ryon's A prompt (`scene_ended_in_control`). The party bar and the
battle screens are not read yet. The name and language on Confirm Choices are not checked. The
daemon's keep-awake is off for this program: its B would back out of the new game's menus.
