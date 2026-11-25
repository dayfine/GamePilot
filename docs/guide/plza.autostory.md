# AutoStory

Plays Pokémon Legends: Z-A's story on the Switch from a new game: it confirms the new game's
choices, skips the opening to the station platform, then walks off the platform and presses through
the arrival scenes to Main Mission 01, where you have free control in Lumiose City. From there it
chases Pancham, takes Chikorita and beats Andi (Main Mission 01), then follows Main Missions 02 and
03: Hotel Z, Taunie's battle, the Pokémon Center, Wild Zone 1's catches (five species in the
party), the research lab and Mable's first research reward, the Rock Smash TM (checkpoint 03.11).

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
cd src && opam exec -- dune exec -- gamepilot checkpoints --program plza.autostory --from 01.00b --to 03.11 --mode testing --backend switch --serial PORT --capture DEVICE \
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
| 03.01 | Down to the lobby |
| 03.02 | Out of Hotel Z |
| 03.02b | Battle Taunie |
| 03.03 | To the rock pile scene |
| 03.03b | Up the ladder to the rooftop scene |
| 03.03c | Off the roof to Station Front |
| 03.04 | Pokemon Center, the Pokedex |
| 03.06 | To the Wild Zones card |
| 03.07 | Into Wild Zone 1: first catches |
| 03.08 | Wild Zone 1: fourth species |
| 03.08a | Wild Zone 1: fifth species |
| 03.08b | Out of Wild Zone 1's far gate |
| 03.09 | From Wild Zone 1's gate into the Research Lab |
| 03.10 | Up the Research Lab's elevator to the Director's Office |
| 03.11 | Mable's research, the Rock Smash TM |

<!-- plans: d20acd695a53 -->
<!-- /generated -->

From Wild Zone 1 on:

- 03.07 catches Fletchling and Bunnelby, weakening them with three attacks when a throw breaks out.
- 03.08 and 03.08a catch a fourth and a fifth species: the camera sweeps until ZL locks on, and
  the nearest Pokémon not marked caught gets the throws.
- 03.08b leaves the zone by its far gate, steering by the map's pin and the minimap's arrow.
- 03.09 and 03.10 walk to the Research Lab and up to the Director's Office.
- 03.11 opens the main menu, goes to Mable's Research and takes the Rock Smash TM.

## When it stops

Reloads and retries:

- The first run starts wherever the console is.
- A retry closes the game and reloads the latest autosave first.
- 01.00b has no autosave to go back to: after it fails, put the console back on Confirm Choices by
  hand.
- 01.01 reloads once more if the platform's controls hint has already faded.
- A checkpoint that follows a passing one starts where it ended, with no reload.
- 03.04 always reloads when it follows 03.03c: its legs need the reload's facing.
- A checkpoint found off its start reloads once and checks its start again, then stops if it is
  still off (`chain_off_start`, or `rocks_not_left` in 03.08). A start left there by a stopped run
  or by the checkpoint before it is put right this way; the log says it reloaded.
- 03.08 and 03.08a reload and try again up to twice when they come up short (`short_of_species`):
  the reload respawns the zone, so a run of bad spawns is luck, not a bug.

Resuming mid-checkpoint (the screen is read first, and steps already done are skipped):

- 01.03 can start inside Andi's battle, or at Urbain's heal after a lost one.
- 01.03 started in the night alley after Andi skips everything and passes.
- 03.02b started at the plaza arch after its map talk skips everything and passes.
- 03.04 started outside the Pokémon Center skips everything and passes.

Start and end checks:

- From 03.03 on, a checkpoint checks its start before it presses anything: the minimap, the party
  count, the A prompt, whether the player is in Wild Zone 1, or (03.08) on Taunie's rocks.
- A start that does not match reloads once (above); still off, it stops the series:
  `chain_off_start`.
- 03.04 also checks its end (outside the Center): `end_off_signature`.

The run folder keeps:

- the story log and the wire log;
- `failure.png`, the last frame of a failed run.

## Known limits

Walks:

- Walks are timed stick legs with no map, so they can miss.
- A missed walk to an A prompt (a door, the clerk, the elevator, the bed): `walk_no_end`.
- A missed walk whose scene never comes: `scene_ended_in_control` or `scene_never_started`.
- A missed walk before a plain scene still passes; the next checkpoint then fails.
- A walk that turns by the minimap's arrow: `heading_missed` after 4 turns, `arrow_unread` when no
  arrow shows for 40 s.
- 03.08b's gate: `gate_not_reached` after 3 runs, `map_pin_not_read`, `in_wild_zone`.

Battles:

- The starter is always Chikorita.
- A lost battle reads as won, so the scene after it fails.
- A battle with no move symbols for 2 minutes: `battle_failed`.
- A battle that comes up during a walk or a scene is not handled: that step fails or times out.

Catching:

- The Run prompt's reader has not seen a console frame yet.
- 03.07: `no_catch` after 6 throws at Fletchling, `still_a_target` after 6 rounds at Bunnelby.
- 03.08 must start on Taunie's rocks: its start check reloads once when it is not, and
  `rocks_not_left` is the catch's own check of the same.
- 03.08 and 03.08a: `short_of_species` when the party does not grow after 12 throws, on each of
  their three attempts.

Readers:

- "Mission complete" is not read.
- The name and language on Confirm Choices are not checked.
- 03.11: `main_menu_not_reached`, `no_reward_lines` (not in Mable's office), `menu_not_closed`.

Keep-awake and camera:

- The daemon keeps the console awake with the right stick (up, then down), not B, which would back
  out of the new game's menus.
- Each checkpoint wakes a dimmed screen the same way before it reads it.
- The walks aim from where the camera looks, so it must be behind the player when a checkpoint
  starts, as after 01.03's scenes or a reload.
