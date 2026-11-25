# Switch bring-up

The first session of GamePilot on a Switch: FireRed (the Switch release) with a post-game save
loaded, a capture card and a PABotBase2 controller board ([Getting started](getting-started.md)
sets up the hardware).

Run one step at a time, from the repo root after a daemon build, and stop at the first step that
fails. Steps 2 to 6 use `PORT` (the board's serial port) and `INDEX` (the capture card), found in
step 1.

## 1. Free the console

Only one program may drive the console. Stop any other program that holds the board or the card
(Pokémon Automation's Computer Control, an idle daemon) and quit it, so its settings are saved.

Nothing may hold the serial port afterwards:

    lsof PORT    # prints nothing

## 2. Find the devices

The board's serial port and the capture card's index. Neither command opens a device:

    GAMEPILOT_LAB_PROFILE=".../SerialPrograms/Profiles/PROFILE" gamepilot switch-devices
    swift daemon/tools/list_capture_devices.swift

`switch-devices` reads the port and the card's id from a Computer Control profile. The Swift tool
lists every capture device with its index and id: `INDEX` is the line with that id.

Pick the card by its id, not its name: several cards can share a name such as "USB Video". With
more than one console attached, check in step 4 that the frame shows FireRed.

## 3. Check the board

GamePilot drives the board as a Pro Controller, in the mode Computer Control set, and never changes
that mode:

    daemon/build/gamepilot_daemon --backend switch --serial PORT --board-check

Expect a line such as `board PABotBase2-ESP32-S3, firmware ..., 921600 baud, mode NS1: Wired Pro
Controller`.

A board in another mode fails here (`board: runs ..., not NS1: Wired Pro Controller`). Pick the
Wired Pro Controller in Computer Control's panel, quit it again and rerun.

## 4. Check one frame

FireRed on screen in the GBA app:

    daemon/build/gamepilot_daemon --backend switch --capture INDEX --capture-check frame.png

Expect `1920x1080 at 60.00 fps` and `geometry ok: picture 1560x1040 at (180, 5)`, then look at
`frame.png`. A wrong picture box means fixing `nso_gba_viewport()` before anything else. The box was
checked against console frames now kept as reader fixtures
(`src/games/frlg/readers/test/images/switch/`): the picture fills it, with black bars left and
right.

A full-screen game (Legends Z-A) has no bars. Its registry descriptor says `viewport = Native` (`docs/guide/README.md`, "Adding a program"), which
`run/run_checkpoints_on_switch.sh PROGRAM` passes to every daemon as `--viewport native`. By hand,
use `gamepilot bring-up --program ID` or the daemon's own `--viewport native`. The check then only
asks that the frame is not mostly dark.

## 5. Press and see it

The player in the overworld, the Start menu closed. If the board line says the console does not see
the controller, press A on the Switch's controller screen and rerun.

    daemon/build/press_latency --serial PORT --capture INDEX --presses 100

It passes on `misses 0` and `spread (p99 - median) ... PASS`, under 50 ms.

## 6. Read the Start menu

The daemon in one terminal, the program in another:

    daemon/build/gamepilot_daemon --backend switch --serial PORT --capture INDEX --log wire.jsonl
    gamepilot run start_menu_poc --console

Expect `start_menu_poc: PASS`. Stop the daemon with Ctrl-C.

## 7. Pre-flight

The save loaded, the player in the overworld. Set `GAMEPILOT_SWITCH_SERIAL`,
`GAMEPILOT_SWITCH_CAPTURE` and `GAMEPILOT_LABLOCK` in `~/.config/gamepilot/env`, then:

    sh run/run_checkpoints_on_switch.sh frlg.mail_glitch \
        --from 01-celadon-setup --to 01-celadon-setup --preflight-only

By hand: `gamepilot run ... --preflight --backend switch --serial PORT --capture INDEX`.

### What it checks

It soft-resets to the save and reads the party, money and items. It compares the place with the
frame kept at 01-celadon-setup's start; the first run has no kept frame, so the place reads NOT READ
until a pass keeps one.

It prints a NEED / READ / VERDICT table: Fly's user, the money the purchases cost, what the
checkpoint before promised, and the free party slots the whole chain needs (two for the Mail Glitch:
Abra in 01, Spearow in 02). Any MISMATCH or NOT READ stops it.

The party is read on each member's summary (species, level, moves), so a field move the plans need
passes when any member knows it.

### A full party

A full party names the members to deposit (`Room_policy`). Never one the plans use, the lead, one
that knows Cut, Fly, Surf or Strength, or the only one that knows a move the plans need. The lowest
level goes first, and nothing is ever released.

With `--make-room MAP` (the save's map, such as `PalletTown`) the runner deposits them itself, as a
generated checkpoint 00-make-room before the chain:

    sh run/run_checkpoints_on_switch.sh src/games/frlg/programs/mail_glitch/plans \
        --from 01-celadon-setup --to 01-celadon-setup --make-room PalletTown

It Flies to the Center nearest MAP (Viridian from Pallet, which has none), deposits with
`pc_deposit`, and walks out to the Fly landing. Its end check re-reads the party and that a member
still knows each needed field move; a pass is saved like any checkpoint. The script skips the
pre-flight with `--make-room`, since the room row would stop the run 00-make-room is there for.

## 8. First checkpoint

    sh run/run_checkpoints_on_switch.sh frlg.mail_glitch \
        --from 01-celadon-setup --to 01-celadon-setup

On the Switch each checkpoint runs once (`--runs 1`) from the game's last save:

- A run that passes, its end checks included, is saved in the game (`--save-after-pass`, the
  default), and the next checkpoint starts from that save. Only that save answers YES to the
  overwrite question.
- A run that fails soft-resets to the last save, and the series stops.
- A failed or stopped run never saves.

The script takes the console's lock and refuses while anything holds the serial port. It runs steps
3, 4 and 7, then the checkpoint with its watch page. It stops the daemons and releases the lock on
every exit, Ctrl-C included.

`--dry-run` runs all of it on fakes (a fake board, a replayed frame, a scratch lock) without
touching the console.

## 9. Hand the console back

Stop every daemon and harness (Ctrl-C, or `kill -TERM`): they release the keys and close the port
and the card, and the board's mode was never changed. Then check:

    pgrep -fl 'gamepilot_daemon|press_latency'    # prints nothing
    lsof PORT                                      # prints nothing

## When it fails

The run folder (`$GAMEPILOT_RUNS/<date>-<id>-testing-N`) holds `failure.png`, the recorded frames and
the story log, all on the run's page in the hub (`http://HOST:47901/runs/<folder>/`). The console is
back at the last save.

Look at the failure frame first: the page's "failure" button jumps there, with the frames before it.
Fix, then rerun the same command; it starts from that save.

A run that failed in the soft reset itself (`soft_reset_failed`, `soft_reset_not_taken`) leaves the
game wherever it stopped. Look at the screen, press B out of any menu, and rerun.

Never answer YES to "There is already a saved file" by hand unless the checkpoint just passed.

## Reference

### Keep-awake

A Switch daemon keeps the console awake by itself (`daemon/src/keep_awake.h`). After 180 s with no
input it presses B, but only while no client batch is queued or running and no client submitted in
that window, so never inside a program's batch. It never presses while a client holds the input
lease, and mGBA daemons have it off.

Each press is a `daemon` line in the run's `wire.jsonl` (`"method":"keepawake"`, the key and the
idle time) and a line in `daemon.out`. `--keepawake SECONDS` changes the wait (0 turns it off) and
`--keepawake-key KEY` the key, a GBA button name; `gamepilot run ... --keepawake N` passes it on.

### Looking at the console by hand

With a daemon holding the console (a run's, or an idle one, for example on port 47920),
`gamepilot ctl` looks and presses through it. Any number of clients may connect. Reads need no lease;
a press takes the daemon's input lease and is refused, naming the holder, while a program or another
person holds it.

    gamepilot ctl --port 47920 status                 # health and who holds the lease
    gamepilot ctl --port 47920 shot now.png           # the current frame
    gamepilot ctl --port 47920 read start_menu        # open, cursor row, the rows' names
    gamepilot ctl --port 47920 --owner me press A --hold 100 --wait 500
    gamepilot ctl --port 47920 dpad DOWN 2
    gamepilot ctl --port 47920 --owner me run steps.txt

`run` takes a file of lines (`press A 100 800`, `dpad DOWN 160 800`, `wait 1000`, `shot NAME`,
`read READER`, `# comment`). It holds the lease for the whole file, prints `ok N LINE` per line and
stops at the first error. Every press is in the daemon's wire log with its owner.

The readers (`gamepilot` with no arguments lists them): `start_menu`, `dialog`, `party_menu`,
`summary` (species on the info page, moves on the moves page), `battle`, `yes_no`, `load_menu`,
`bag`. `sh run/test_ctl.sh` checks all of it against the fake board and a replayed capture.

### Recording

A Switch run's daemon saves a 640-wide JPEG of the frame every second, and one at each story event
and at a failure, into the run folder's `frames/`. `index.jsonl` lists them with the step and time,
and `--no-record` turns it off. At about 41 KB a frame, that is about 150 MB an hour of console time.
The hub's page of a finished run scrubs through them (`docs/design/Watch-Page.md`, Past runs).

### Frames to capture for reader fixtures

Save them from the watch page or with `--capture-check`:

- the title screen;
- the recap after CONTINUE, and the black screen after it;
- the Start menu with the cursor on SAVE and on POKéDEX;
- the save info box with "Would you like to save the game?";
- "SAVING... DON'T TURN OFF THE POWER" and "<name> saved the game.";
- a save error, if one ever shows.

The load menu and the overwrite question are already captured.
