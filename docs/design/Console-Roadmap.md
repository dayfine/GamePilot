# Console roadmap: from the lab app to the daemon (2026-11-23)

Who drives console B (the lab Switch), and the steps to move it from the PA/CC lab app
(SerialPrograms on the fork) to GamePilot's daemon. Each step has a "done when" line; we take
them in order and tick them off here.

## Where we are

- **Two drivers.** The fork's lab app (SerialPrograms, profile lab-B) runs the C++ programs:
  BDSP AutoStory, FRLG RNG, PLZA. GamePilot's daemon owns the capture card (OpenCV) and the
  controller (the Pro Controller protocol from CoreLib) for GamePilot programs. Both take the same
  console lock (`lablock.sh -c B`), so only one holds the console at a time.
- **Looking at the console by hand** goes through the daemon with `gamepilot ctl` (`shot`, `read`,
  `press`, `dpad`, `run FILE` in labB.sh's format; `switch-bring-up.md`), next to a running
  program: the daemon serves many clients and one input lease. The lab app's inbox (`labB.sh`)
  is only for its own C++ programs.
- **Agents** see the console through pa-lab's MCP (`console_status`, read-only), which reads the
  lab app's files.
- **The watch page** (`Watch-Page.md`) shows a daemon run live (MJPEG, probe boxes, log, plan,
  Stop) on the LAN hub at port 47901.

## Decisions

1. **GamePilot on the Switch never needs the lab app.** The daemon is the only process that
   touches the board and the card during a GamePilot run.
2. **The lab app stays only for C++ programs not yet ported.** No new lab-app features (inbox
   commands, panel switching, CFR). It retires game by game as each game's programs move to
   GamePilot.
3. **Hand control moves to the daemon and the watch page**: the pad from `Control-UI.md` (order
   item 3). It replaces `labB.sh` and CFR for inspection and recovery.
4. **MCP keeps pa-lab as the front** (`Layered-Automation-Stack.md` §8), with the daemon as a second
   adapter beside the lab app. When the lab app retires, its adapter goes and the daemon's stays.

## Steps

| # | Step | Done when |
|---|---|---|
| 1 | **Switch runner** (`tools/run_checkpoints_on_switch.sh`): lab lock, refuse while the lab app holds the board or card, bring-up checks, soft reset to the last save, in-game save after a clean pass, preflight of the save, always hand back | merged; dry run passes on the fake board and a replayed capture |
| 2 | **Bring-up on console B** (`switch-bring-up.md`): board mode, one frame, geometry, latency gate, start menu, preflight of the post-game save | every checklist line ticked on the console; frames for the title/continue/save readers captured |
| 3 | **Mail Glitch on the Switch**: mg-01 → mg-06, one clean pass each with end checks green, in-game save after each (mg-04 holds the first full grind) | mg-06 copies an Antidote on console B |
| 4a | **`gamepilot ctl`** (this PR; live check open): the daemon serves many clients with one input lease (contracts v1.9); `ctl` presses, reads named FRLG readers, takes shots and runs labB.sh-format scripts through it; the watch page's health shows the holder | `tools/test_ctl.sh` green on the fake board; ctl against the idle console B daemon |
| 4 | **Manual mode**: `gamepilot_daemon --switch --manual` holds the board and card with no program; the watch page gets a pad (A/B/X/Y/L/R/±/HOME, D-pad, hold time) and "save frame", behind the per-series token like Stop; every press goes to the run log | a whole FireRed title → Continue → overworld done from a phone on the LAN, no lab app open |
| 5 | **Hand-control lease** (lease done with 4a; the pad's part open): the pad takes the input lease (`Control-UI.md`), a running program pauses or refuses while a person holds it, and the hold ends after a quiet timeout | a program and the pad never send input at the same time (case-table tests + one live check) |
| 6 | **pa-lab daemon adapter**: `console_status`, `frame`, `press` (leased), `run_checkpoint`, `stop` over the daemon's JSON-RPC | an agent runs one checkpoint and reads its result through MCP without the lab app |
| 7 | **Retire the lab app per game**: once a game's programs pass on the daemon, its lab panels, inbox scripts and pa-lab lab-app paths for it go | FRLG first (after step 3); BDSP and PLZA once ported |

Steps 4–6 need no console until their live check, so they can run while console B does other work.

## Shared logic across games

Porting is easier when the C++ games already share data. On the fork, the AutoStory seam stack
(#795 → #801) lands first, then FRLG adopts it. After that, the work goes into data both stacks read,
not into reshaping C++ code: checkpoint plans and story events as JSON, maps and route targets,
reader thresholds and templates, the movement table, and **move choice** (FRLG already picks
super-effective moves; BDSP needs the same, from one shared type chart and policy instead of a
second copy).

## Open

- Pad over the LAN: allowed for any viewer with the series token, or only from localhost? The
  recommendation is the token, the same rule as Stop.
- Audio: not needed by any program yet; MJPEG stays until one does.
