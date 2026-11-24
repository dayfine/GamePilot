# Switch bring-up (console B)

The first session of GamePilot on the Switch: FireRed (the Switch release) on console B, the user's
post-game save loaded. One command per step; stop at the first step that fails. Commands run from
the repo root after a daemon build. `PORT`, `INDEX` and the board line come from step 1.

**0. Take console B from the lab app.** Stop its program, turn keepawake off and quit the lab-B
app (it saves its settings on exit). Nothing may hold the port or the card:

    lsof /dev/cu.usbmodem5C940521411    # prints nothing

**1. Devices.** The lab's names, then the card's index (enumerates, opens nothing):

    GAMEPILOT_LAB_PROFILE=".../SerialPrograms/Profiles/lab-B" gamepilot switch-devices
    swift tools/list_capture_devices.swift    # INDEX: the line with id 0x110000534d2109

On 2026-11-23 these were serial port `/dev/cu.usbmodem5C940521411` and card id `0x110000534d2109`
("USB Video", a name three cards share, so pick by id; on 2026-11-23 it was index 1, and index 0 showed console A. Check the frame shows FireRed).

**2. Board handshake and mode check.** GamePilot drives the board as a Pro Controller in the mode the
lab app keeps it in and never changes that mode:

    daemon/build/gamepilot_daemon --backend switch --serial PORT --board-check

Expect `board PABotBase2-ESP32-S3, firmware 2026092800, link 2026061800, messages 2026061805,
921600 baud, mode NS1: Wired Pro Controller`, as the lab app's log shows that board. A board in
another mode fails here (`board: runs ..., not NS1: Wired Pro Controller`): pick the Wired Pro
Controller in the lab-B app's panel, quit it again and rerun.

**3. One frame and its geometry.** FRLG on screen in the GBA app:

    daemon/build/gamepilot_daemon --backend switch --capture INDEX --capture-check frame.png

Expect `1920x1080 at 60.00 fps` and `geometry ok: picture 1560x1040 at (180, 5)`; look at
`frame.png`. A wrong picture box means fixing `nso_gba_viewport()` before anything else. Checked on
2026-11-23 against console B's own frames (the load menu, Pallet Town, the overwrite question, now
reader fixtures under `src/games/frlg/readers/test/images/switch/console-b-20261123/`): the
picture fills that box exactly, black bars left and right.

**4. Press and see it.** Player in the overworld, start menu closed. If the board line says the
console does not see the controller, press A on the Switch's controller screen and rerun.

    daemon/build/press_latency --serial PORT --capture INDEX --presses 100

Gate (PR #44, F4): `misses 0` and `spread (p99 - median) ... PASS`, under 50 ms.

**5. Read the start menu.** Daemon in one terminal, program in another:

    daemon/build/gamepilot_daemon --backend switch --serial PORT --capture INDEX --log wire.jsonl
    gamepilot run start_menu_poc --console

Expect `start_menu_poc: PASS`. Stop the daemon with Ctrl-C.

**6. Pre-flight.** The save loaded, the player in the overworld. Set `GAMEPILOT_SWITCH_SERIAL`,
`GAMEPILOT_SWITCH_CAPTURE` and `GAMEPILOT_LABLOCK` (the env file, `~/.config/gamepilot/env`), then:

    sh tools/run_checkpoints_on_switch.sh --program frlg.mail_glitch \
        --from mg-01 --to mg-01 --preflight-only

(or `gamepilot checkpoints ... --preflight --backend switch --serial PORT --capture INDEX`). It
soft-resets to the save, reads the party, money and items, compares the place with the frame
kept at mg-01's start, and prints a NEED / READ / VERDICT table: Fly's user, the money the
purchases cost, what the checkpoint before promised, and the free party slots the whole chain
needs (Abra in mg-01, Spearow in mg-02: two). Any MISMATCH or NOT READ stops it. A full party
names the members that could go to a PC (never one the plans use or one that knows Cut, Fly,
Surf or Strength); depositing is by hand for now. The first run has no kept frame, so the place
reads NOT READ until a pass keeps one.

**7. First checkpoint.** The policy on the Switch: each checkpoint runs once (`--runs 1`) from
the game's last save. A run that passes, its end checks included, is saved in the game
(`--save-after-pass`, the default; the save answers YES to the overwrite question only there) and
the next checkpoint starts from that save. A run that fails soft-resets to the last save and the
series stops. A failed or stopped run never saves.

    sh tools/run_checkpoints_on_switch.sh --program frlg.mail_glitch \
        --from mg-01 --to mg-01

The script takes console B's lab lock, refuses while anything holds the serial port or the lab
app runs, runs steps 2, 3 and 6, then the checkpoint with the watch page, and stops the daemons
and releases the lock on every exit, Ctrl-C included. `--dry-run` runs all of it on the fakes
(fake board, a replayed frame, a scratch lock) without touching the console.

**Keep-awake.** A Switch daemon keeps the console awake by itself: after 180 s with no input
it presses B, only while no client batch is queued or running and no client submitted in that
window, so never inside a program's batch (`daemon/src/keep_awake.h`). Each press is a `daemon`
line in the run's `wire.jsonl` (`"method":"keepawake"`, the key and the idle time) and a line in
`daemon.out`. `--keepawake SECONDS` changes the wait (0 turns it off; `--keepawake-key KEY` the
key, a GBA button name); `gamepilot checkpoints ... --keepawake N` passes it on. mGBA daemons
have it off. It replaces `~/BDSPLab/gp_keepawake.py`, a second client the daemon's one-client
rule refused ("busy: another client is connected"): an idle daemon holding console B now keeps
it awake, and the script is no longer needed while one runs.

**Recording.** A Switch run's daemon also saves a 640-wide JPEG of the frame every second, and
one at each story event and at a failure, into the run folder's `frames/` (`index.jsonl` lists
them with the step and time; `--no-record` turns it off). About 41 KB a frame, so about 150 MB
an hour of console time. The hub's page of the finished run scrubs through them
(`docs/design/Watch-Page.md`, Past runs).

**When it fails on the Switch.** The run folder (`$GAMEPILOT_RUNS/<date>-<id>-testing-N`) has
`failure.png`, the recorded frames and the story log, all on the run's page in the hub
(`http://HOST:47901/runs/<folder>/`); the console is back at the last save. Look at the failure
frame first (the page's "failure" button jumps there, with the frames before it), fix, then
rerun the same command: it starts from that save. A run that failed in
the soft reset itself (`soft_reset_failed`, `soft_reset_not_taken`) leaves the game wherever it
stopped: look at the screen, B out of any menu, and rerun. Never answer YES to "There is already
a saved file" by hand unless the checkpoint just passed.

Frames to capture during bring-up, for reader fixtures (save them from the watch page or
`--capture-check`): the title screen; the load menu (have it); the recap after CONTINUE; the
black screen after CONTINUE; the Start menu with the cursor on SAVE and on POKéDEX; the save
info box with "Would you like to save the game?"; the overwrite question (have it); "SAVING...
DON'T TURN OFF THE POWER"; "<name> saved the game."; a save error, if one ever shows.

**8. Hand console B back.** Stop every daemon and harness (Ctrl-C, or `kill -TERM`; they release the
keys and close the port and the card; the board's mode was never changed), then check:

    pgrep -fl 'gamepilot_daemon|press_latency'    # prints nothing
    lsof /dev/cu.usbmodem5C940521411              # prints nothing

Relaunch the lab-B app as usual and turn keepawake back on.
