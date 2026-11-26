# AutoStory

Plays Pokémon Legends: Z-A's story on the Switch from a new game, one checkpoint at a time: it
launches the game from the Switch HOME, makes and confirms the new game's choices, skips the
opening, then follows the Main Missions, walking the routes, pressing through the scenes and
fighting the story battles. The checkpoints table below lists the ones it plays.

<!-- generated:backends -->
Runs on: the Switch.
<!-- /generated -->

## Before you start

For 00.00-new-game, delete PLZA's save (`gamepilot ctl delete-save plza`, look at the screen, then
`gamepilot ctl delete-save --confirm`) and leave the Switch on HOME, PLZA's tile among the first 8.

Or start a new game by hand up to its Confirm Choices screen (language, look and name) and start at
01.01-to-the-platform (`--from 01.01`); or put the console on the station platform with free
control, the controls hint showing, to run 01.02-platform-to-plaza alone (`--from 01.02`).

The Switch's capture must be the whole 1920x1080 picture (the daemon's `--viewport native`).

### The new game's choices

00.00-new-game's choices are the program's options, one `--options KEY=VALUE` each; repeat the flag
for more. Pass them on the command line rather than editing the plan:

<!-- generated:options -->
Give each as `--options KEY=VALUE`:

| Key | Values | When not given | What it chooses |
|---|---|---|---|
| `language` | en \| es-ES \| es-419 \| fr \| de \| it \| ja \| zh-Hant | optional | the new game's language (00.00-new-game; not given: the plan's) |
| `look` | 1 to 8 | optional | the new game's look, left to right along the top row, then the bottom (not given: the plan's) |
| `name` | text | optional | the player's name: at most 12 characters (6 in Japanese and Chinese), letters, digits and - / : ' , . ? ! (not given: the plan's) |
<!-- /generated -->

A key not given keeps 00.00-new-game's plan's arg. Any other key, a key given twice, a value its
key does not take, a name its language cannot take, and options on a series that does not start at
00.00-new-game are refused before the console moves. The run prints the choices it plays, and its
run.json and watch page show the options. In French with look 5, for example:

```sh
cd src && opam exec -- dune exec -- gamepilot run plza.autostory --from 00.00-new-game --to 03.15-mable-reward --mode testing --backend switch --serial PORT --capture DEVICE \
    --watch --options language=fr --options look=5
```

## Running it

<!-- generated:commands -->
```sh
# the Switch: each checkpoint once, from where the console is
cd src && opam exec -- dune exec -- gamepilot run plza.autostory --from 00.00-new-game --to 03.15-mable-reward --mode testing --backend switch --serial PORT --capture DEVICE \
    --watch
```
<!-- /generated -->

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 00.00-new-game | A new game from HOME to Confirm Choices |
| 01.01-to-the-platform | Confirm Choices to the station platform |
| 01.02-platform-to-plaza | The platform to Main Mission 01 |
| 01.03-chase-pancham | Main Mission 01: chase Pancham to the battle area |
| 01.04-starter-and-andi | Main Mission 01: the starter and Andi |
| 02.01-battle-brigitte | Main Mission 02: Battle Zone to Brigitte |
| 02.02-to-hotel-z | Main Mission 02: after Brigitte to Hotel Z |
| 02.03-hotel-z-lobby | Main Mission 02: into the Hotel Z lobby |
| 02.04-hotel-check-in | Main Mission 02: Hotel Z check-in |
| 02.05-to-room-202 | Main Mission 02: Hotel Z elevator to Room 202 |
| 02.06-night-in-room-202 | Main Mission 02: the night in Room 202 |
| 02.07-first-evening | Main Mission 02: the first evening to Main Mission 03 |
| 03.01-down-to-the-lobby | Down to the lobby |
| 03.02-out-of-hotel-z | Out of Hotel Z |
| 03.03-battle-taunie | Battle Taunie |
| 03.04-rock-pile-scene | To the rock pile scene |
| 03.05-up-to-the-rooftop | Up the ladder to the rooftop scene |
| 03.06-off-the-roof | Off the roof to Station Front |
| 03.07-pokemon-center | Pokemon Center, the Pokedex |
| 03.08-wild-zones-card | To the Wild Zones card |
| 03.09-first-catches | Into Wild Zone 1: first catches |
| 03.10-fourth-species | Wild Zone 1: fourth species |
| 03.11-fifth-species | Wild Zone 1: fifth species |
| 03.12-out-of-wild-zone-1 | Out of Wild Zone 1's far gate |
| 03.13-into-research-lab | From Wild Zone 1's gate into the Research Lab |
| 03.14-lab-elevator | Up the Research Lab's elevator to the Director's Office |
| 03.15-mable-reward | Mable's research, the Rock Smash TM |

<!-- plans: ba90cc1a9e8a -->
<!-- /generated -->

00.00-new-game closes any running game, finds PLZA's tile on HOME by its title, starts it, picks
the language on its list, tilts to the look, types the name on the Switch keyboard and presses +
until Confirm Choices shows.

01.01 confirms the choices, skips the opening and waits for the platform. 01.02 sets the text
speed to fast, walks down the platform and right to the white fade, and presses through the arrival
scenes (Plus skips the president's ad) until the controls hint shows again.

01.03 walks after Pancham, presses B through the scene to its choice and takes "Battle with
Pokemon!". 01.04 walks to Chikorita and talks, picks it, presses through the tutorial cards to the
battle, and fights Andi with the most effective move under ZL until Andi speaks.

Main Mission 02 walks from the Battle Zone to Brigitte and beats her Cleffa, skips the street's
cutscene, follows Taunie to Hotel Z, then checks in, rides the elevator to Room 202 and rests until
morning. A walk that ends at an A prompt (a door, the clerk, the elevator, the bed) is followed by a
scene that presses A through the prompt first; a scene with a start window waits that long for the
scene to begin before it counts free control as the end.

Main Mission 03 leaves Room 202 by the elevator to the lobby, out of Hotel Z, and through Taunie's
battle (Totodile, then Tepig) and her talk over the map; past the rock pile, up the side street's
ladder (stepping along the wall until "Climb Up" shows) and off the roof; into the Pokémon Center
for the Pokédex, then on to Wild Zone 1's gate and the Wild Zones card. Some walks run with B held.

In Wild Zone 1 it runs to the gate's A prompt with B held, catches the tutorial's Fletchling (each
throw locks on with ZL, then throws with ZL and ZR; one that breaks out into a battle weakens the
target first) and Bunnelby (attacks until three land, then a throw, sweeping the camera when the
target is out of sight).

From Taunie's rocks it catches a fourth and a fifth species: the camera sweeps until ZL locks on,
and the nearest Pokémon not marked caught gets the throws. It leaves by the far gate, steering by
the map's pin and the minimap's arrow. In the Research Lab it rides the elevator to the third
floor and claims Mable's research reward from the main menu.

## When it stops

Reloads:

- The first run starts wherever the console is.
- A second run of a checkpoint (`--runs 2`) first closes the game and reloads the latest autosave.
  00.00-new-game and 01.01 have no autosave to go back to: their second run is refused. After
  00.00-new-game fails, delete the save again and go back to HOME, or make the choices by hand and
  start at 01.01.
- 01.02 reloads once more if the platform's controls hint has already faded.
- A checkpoint that follows a passing one starts where it ended, with no reload; 03.07 always
  reloads when it follows another, since its walk needs the reload's facing.
- A checkpoint found off its start (below) reloads once and checks its start again, then stops if
  it is still off (`chain_off_start`; in 03.10 also when the catch finds the player off Taunie's
  rocks); the log says it reloaded.
- 03.10 and 03.11 reload and try again up to twice when they come up short (`short_of_species`):
  the reload respawns the zone, so a run of bad spawns is luck, not a bug.

Start and end checks:

- From 03.04 on, a checkpoint whose plan names a start reads it before it presses anything: the
  minimap recorded at its start, the party count, the A prompt, whether the player is in Wild Zone
  1, or (03.10) on Taunie's rocks: `chain_off_start` when one differs.
- 03.07 also checks its end (outside the Center): `end_off_signature`.
- A checkpoint whose plan names no start check logs START UNCHECKED and goes on.

Resuming mid-checkpoint (the screen is read first, and steps already done are skipped):

- 01.04 can start inside Andi's battle, or at Urbain's heal after a lost one.
- 03.03 started at the plaza arch after its map talk skips everything and passes; so does 03.07
  started outside the Pokémon Center.

Failures:

- 00.00-new-game refuses choices it cannot play before it presses anything (`new_game_refused`),
  and stops with `new_game_failed` when PLZA's tile is not among HOME's first 8 (play it once so its
  tile moves to the front), a screen does not show or a highlight does not reach the choice.
- 01.01 on any screen but Confirm Choices presses nothing and fails `not_on_confirm_choices`.
- A walk whose end never shows fails `walk_no_end`; one that no scene takes, `walk_no_scene`.
- A scene that ends in free control where a choice or a battle was due fails
  `scene_ended_in_control` (the walk before it stopped short).
- A scene that presses A first, on free control with no A prompt (two reads 300 ms apart), fails
  `prompt_not_seen` before pressing anything: the walk before it stopped short.
- 03.05's ladder: `ladder_not_found` when no step along the wall shows "Climb Up".
- The run to a gate: `gate_not_reached` when no A prompt shows in time (a day/night change gets
  one more run).
- A catch: `no_catch` when no throw is followed by the caught card, `still_a_target` when a target
  still locks on after the last round.
- 03.10 and 03.11: `short_of_species` when the party does not grow after 12 throws, on each of
  their three attempts.
- Leaving Wild Zone 1: `gate_not_reached` after 3 runs, `map_pin_not_read`, `in_wild_zone`.
- Mable's reward: `main_menu_not_reached` when X never opens the main menu, `no_reward_lines` when
  her research page shows no lines (nothing was claimed).
- 03.03's map talk: `map_talk_timeout` when the party bar never holds within 2 minutes.
- A lost battle (a black fade with the lead's HP near empty) fails `battle_lost`. Run 01.04 again
  (`--from 01.04`): it goes on at Urbain's heal, at Andi's rematch or inside the battle. A battle
  whose move symbols never show fails `battle_failed`.
- The run folder keeps the story log, the wire log and `failure.png`, the last frame of a failed
  run.

## Known limits

- Walks are timed stick legs with no map, so they can miss.
- The daemon keeps the console awake with the right stick (up, then down), not B, which would back
  out of the new game's menus.

## How it works

`Plza_checkpoint_series.Checkpoint_series` runs each checkpoint in its own daemon and run folder,
with the watch page, and `Plza_series.Runs` gives it the story's attempt.
`Plza_checkpoint_series.Run_attempts` decides when to reload (`Plza_autostory.Game_reload`) and
try again, and `Plza_autostory.Start_signature` checks the start and end.

`Plza_autostory.Story_game` gives the engine a handler for each game action a plan names, ported
from the fork's PLZA AutoStory and built on `Plza_story` and `Plza_walk` over its `Steps`; any
other event fails `no_handler`.

A walk or scene that meets the battle early jumps to the battle event
(`Plza_autostory.Battle_jump`), and `skip_if` flags are read from the screen
(`Plza_autostory.Resume_flags`). `Plza_autostory.Live_story_screen` reads the screen into a
`Plza_story.Look` from PLZA's readers.
