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
cd src && opam exec -- dune exec -- gamepilot checkpoints --program plza.autostory --from 01.00b --to 02.01 --mode testing --backend switch --serial PORT --capture DEVICE \
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

<!-- plans: 8fb2903284ca -->
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

Only 01.00b to 02.01 so far. 01.02's chase, 01.03's walk to Chikorita and 02.01's walk through
the Battle Zone are timed stick legs with no map, so they can miss; the chase then stops on Ryon's
A prompt (`scene_ended_in_control`), the walk to Chikorita with `walk_no_end`, and the Battle Zone
walk with `scene_ended_in_control` when Brigitte's talk never starts. The starter is always Chikorita. The
battle holds ZL and picks the most effective move from the symbols it shows; the move is pressed
with ZL still held. A battle that never sees them fails with `battle_failed` after 2 minutes, and
a lost battle reads as won (the talk after it looks the same), so the scene after it then fails. The
party bar is read from its empty last slot, so a full party of six would not show it; "mission
complete" is not read. After Brigitte, a scene that never starts within 45 s fails with
`scene_never_started`. The name and language on Confirm Choices are not checked. The
daemon's keep-awake nudges the right stick for this program, not B, which would back out of the new
game's menus; and each checkpoint wakes the screen with the right stick before it reads it, since a
dimmed screen reads as nothing.
