# AutoStory

Plays Pokémon Legends: Z-A's story on the Switch from a new game: it confirms the new game's
choices, skips the opening to the station platform, then walks off the platform and presses through
the arrival scenes to Main Mission 01, where you have free control in Lumiose City. From there it
chases Pancham, answers "Battle with Pokémon!", walks to Chikorita, takes it, and beats Andi's
Pancham, through MAIN MISSION 01 COMPLETE to the Main Mission 02 banner.

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
cd src && opam exec -- dune exec -- gamepilot checkpoints --program plza.autostory --from 01.00b --to 03.04 --mode testing --backend switch --serial PORT --capture DEVICE \
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
| 03.02b | Battle Taunie |
| 03.02 | Out of Hotel Z |
| 03.03b | Up the ladder to the rooftop scene |
| 03.03c | Off the roof to Station Front |
| 03.03 | To the rock pile scene |
| 03.04 | Pokemon Center, the Pokedex |

<!-- plans: 630d6c8f0804 -->
<!-- /generated -->

## When it stops

The first run starts wherever the console is. If 01.01 does not see the platform's controls hint,
which fades after a few seconds idle, it reloads the platform's autosave and looks again. A later run of 01.01 first closes the game and
starts it again from HOME's first tile to load the latest autosave (the platform's for 01.01,
Main Mission 01's in Vert District for 01.02, the battle area's for 01.03); 01.00b cannot be
reloaded,
so after it fails, put the console back on Confirm Choices by hand and run it again. 01.03 can
also start inside Andi's battle, or at Urbain's heal and Andi's challenge after a lost one: it
looks at the screen first and skips the walk to Chikorita, and the scene to the battle when the
battle is already up. Started in the night alley after Andi (the party bar up, nothing over it),
01.03 skips every step and passes; 02.01 starts there. Each run keeps its log, wire log and a `failure.png` in its run folder.

## Known limits

Only 01.00b to 03.03c so far. 01.02's chase, 01.03's walk to Chikorita and the walks of 02.01 to
03.03c are timed stick legs with no map, so they can miss; the chase then stops on Ryon's
A prompt (`scene_ended_in_control`), the walk to Chikorita with `walk_no_end`, and the Battle Zone
walk with `scene_ended_in_control` when Brigitte's talk never starts. In 02.02, a walk to the
blocked street that misses fails with `walk_no_end` (no black fade), one to the gate that misses
its A prompt with `walk_no_end`, and the passage walk that misses Hotel Z leaves its scene to fail
with `scene_never_started` after 45 s. A walk with no end followed by a plain scene (03.03's gate walk before the rock
pile) passes even when it misses, since the scene ends on control; the next checkpoint then fails.
From 03.03 on, walks run (B held, each leg for its walk time over 1.65), as the fork does; the
earlier ones walk, since running was checked on the console only from there. From 02.03 on, a walk
that never reaches its A prompt
(a door, the clerk, the elevator, the bed) fails with `walk_no_end`. The starter is always Chikorita. The
battle holds ZL and picks the most effective move from the symbols it shows; the move is pressed
with ZL still held. A battle that never sees them fails with `battle_failed` after 2 minutes, and
a lost battle reads as won (the talk after it looks the same), so the scene after it then fails. The
party bar is read from its empty last slot, so a full party of six would not show it; "mission
complete" is not read. After Brigitte, a scene that never starts within 45 s fails with
`scene_never_started`. The name and language on Confirm Choices are not checked. The
daemon's keep-awake nudges the right stick up and down for this program, not B, which would back out
of the new game's menus; and each checkpoint wakes the screen the same way before it reads it, since a
dimmed screen reads as nothing. Up and down, never sideways: the walks' legs are aimed from where the
camera looks, so they need it behind the player as the checkpoint starts (after 01.03's scenes, or
after a reload). A checkpoint that follows a passing one starts where it ended, with no reload; only
a retry reloads.
