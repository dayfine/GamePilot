# AutoStory

Plays Pokémon Legends: Z-A's story on the Switch from a new game, one checkpoint at a time: it
confirms the new game's choices, skips the opening, then follows the Main Missions, walking the
routes, pressing through the scenes and fighting the story battles. The checkpoints table below
lists the ones it plays.

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
cd src && opam exec -- dune exec -- gamepilot run plza.autostory --from 01.00b --to 02.07 --mode testing --backend switch --serial PORT --capture DEVICE \
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
| 01.03 | Main Mission 01: the starter and Andi |
| 02.01 | Main Mission 02: Battle Zone to Brigitte |
| 02.02 | Main Mission 02: after Brigitte to Hotel Z |
| 02.03 | Main Mission 02: into the Hotel Z lobby |
| 02.04 | Main Mission 02: Hotel Z check-in |
| 02.05 | Main Mission 02: Hotel Z elevator to Room 202 |
| 02.06 | Main Mission 02: the night in Room 202 |
| 02.07 | Main Mission 02: the first evening to Main Mission 03 |

<!-- plans: cbcbedb7cf67 -->
<!-- /generated -->

01.00b confirms the choices, skips the opening and waits for the platform. 01.01 sets the text
speed to fast, walks down the platform and right to the white fade, and presses through the arrival
scenes (Plus skips the president's ad) until the controls hint shows again.

01.02 walks after Pancham, presses B through the scene to its choice and takes "Battle with
Pokemon!". 01.03 walks to Chikorita and talks, picks it, presses through the tutorial cards to the
battle, and fights Andi with the most effective move under ZL until Andi speaks.

Main Mission 02 walks from the Battle Zone to Brigitte and beats her Cleffa, skips the street's
cutscene, follows Taunie to Hotel Z, then checks in, rides the elevator to Room 202 and rests until
morning. A walk that ends at an A prompt (a door, the clerk, the elevator, the bed) is followed by a
scene that presses A through the prompt first; a scene with a start window waits that long for the
scene to begin before it counts free control as the end.

## When it stops

- The run starts wherever the console is; nothing reloads, so each checkpoint runs once
  (`--runs 2` is refused).
- 01.00b on any screen but Confirm Choices presses nothing and fails `not_on_confirm_choices`.
- When the platform's controls hint has faded (it does after a few seconds idle), 01.01 would reload
  the latest autosave to see it fresh; the runner cannot reload yet, so it fails `no_reload`. Start
  01.01 right after 01.00b, or move the stick by hand first.
- A walk whose white fade never shows fails `walk_no_end`.
- A scene that ends in free control where a choice or a battle was due fails
  `scene_ended_in_control` (the walk before it stopped short).
- A scene that presses A first, on free control with no A prompt (two reads 300 ms apart), fails
  `prompt_not_seen` before pressing anything: the walk before it stopped short.
- A lost battle (a black fade with the lead's HP near empty) fails `battle_lost`. Run 01.03 again
  (`--from 01.03`): it reads the screen and skips what is done, so it goes on at Urbain's heal, at
  Andi's rematch or inside the battle. A battle whose move symbols never show fails `battle_failed`.
- The run folder keeps the story log, the wire log and `failure.png`, the last frame of a failed
  run.

## Known limits

- Walks are timed stick legs with no map, so they can miss.
- The daemon keeps the console awake with the right stick (up, then down), not B, which would back
  out of the new game's menus.

## How it works

`Plza_series.Runs` runs each checkpoint in its own daemon and run folder, with the watch page.
`Plza_autostory.Story_game` gives the engine its handlers: the walk (`Plza_walk.Walk`, ported from
`PokemonLZA_AutoStoryWalks.cpp`), the scene machine (`Plza_story.Scene_machine`), the story battle
(`Plza_story.Battle`) and the other game actions in `Plza_story`, over its `Steps`;
any other event fails `no_handler`.

A walk or scene that meets the battle early jumps to the battle event
(`Plza_autostory.Battle_jump`), and `skip_if` flags are read from the screen
(`Plza_autostory.Resume_flags`). `Plza_autostory.Live_story_screen` reads the screen into a
`Plza_story.Look` from PLZA's readers.
