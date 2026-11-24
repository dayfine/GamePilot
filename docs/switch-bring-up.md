# Switch bring-up (console B)

The first session of GamePilot on the Switch: FireRed in the NSO GBA app on console B, the user's
post-game save loaded. One command per step; stop at the first step that fails. Commands run from
the repo root after a daemon build. `PORT`, `INDEX` and the board line come from step 1.

**0. Take console B from the lab app.** Stop its program, turn keepawake off and quit the lab-B
app (it saves its settings on exit). Nothing may hold the port or the card:

    lsof /dev/cu.usbmodem5C940521411    # prints nothing

**1. Devices.** The lab's names, then the card's index (enumerates, opens nothing):

    GAMEPILOT_LAB_PROFILE=".../SerialPrograms/Profiles/lab-B" gamepilot switch-devices
    swift tools/list_capture_devices.swift    # INDEX: the line with id 0x1140000534d2109

On 2026-11-23 these were serial port `/dev/cu.usbmodem5C940521411` and card id `0x1140000534d2109`
("USB Video", a name three cards share, so pick by id).

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
`frame.png`. A wrong picture box means fixing `nso_gba_viewport()` before anything else.

**4. Press and see it.** Player in the overworld, start menu closed. If the board line says the
console does not see the controller, press A on the Switch's controller screen and rerun.

    daemon/build/press_latency --serial PORT --capture INDEX --presses 100

Gate (PR #44, F4): `misses 0` and `spread (p99 - median) ... PASS`, under 50 ms.

**5. Read the start menu.** Daemon in one terminal, program in another:

    daemon/build/gamepilot_daemon --backend switch --serial PORT --capture INDEX --log wire.jsonl
    gamepilot run start_menu_poc --console

Expect `start_menu_poc: PASS`. Stop the daemon with Ctrl-C.

**6. First checkpoint, testing mode.** The user loads the save at mg-01's start:

    gamepilot checkpoints src/games/frlg/programs/mail_glitch/plans --from mg-01 --to mg-01 \
        --mode testing --runs 1 --backend switch --serial PORT --capture INDEX --watch

The console has no save states: the run starts from the loaded save and its `end.ss` and
`failure.ss` are not written (the log says so); `failure.png` is.

**7. Hand console B back.** Stop every daemon and harness (Ctrl-C, or `kill -TERM`; they release the
keys and close the port and the card; the board's mode was never changed), then check:

    pgrep -fl 'gamepilot_daemon|press_latency'    # prints nothing
    lsof /dev/cu.usbmodem5C940521411              # prints nothing

Relaunch the lab-B app as usual and turn keepawake back on.
