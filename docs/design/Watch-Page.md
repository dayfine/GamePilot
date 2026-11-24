# Watch page (2026-11-23)

`gamepilot checkpoints ... --watch` opens a page for watching one run live, the same on mGBA and
the Switch, from any browser: the game frame with the subscribed probe boxes and their latest
results, the chain of checkpoints the run goes through, the checkpoint's events (done, current,
failed, skipped), the story log, the daemon's health, and a Stop button. It is step 1 and part of step 2 of `Control-UI.md`.

## Data flow

```
                 frame, probes, status (the daemon has them)
 browser  <-- GET /events (Server-Sent Events) ---------------+
          <-- GET /frame (polled, <= 5/s) --------------------+-- daemon (server loop)
          --- POST /stop ------------------------------------>+      |  ^
                                                                    |  | watch.plan, watch.log
                                     stop (notification) ---------->+  | (notifications, not in
                                                                    v  |  wire.jsonl)
                                                         OCaml program (Live session)
```

- **The daemon serves the page** (`daemon/src/watch_server.*`, `server_watch.cpp`): a small HTTP
  server on its own port (`--watch-port`; the runner asks for a free one), polled by the same loop as
  the program's socket, no thread of its own. It already holds the frame, the probes and the health; the page is
  one HTML/JS file (`daemon/watch/watch.html`) compiled in and served as is. No new dependency.
- **The program publishes what only it knows**: the plan's states and its story lines, as two
  notifications (`watch.plan`, `watch.log`, contract v1.6) sent through the `show_plan`/`show_log`
  effects. Notifications need no answer, so they cost the program nothing but a write. The daemon
  keeps the latest plan and the last 1000 lines for a page that connects later.
- **The chain is the runner's** (`watch.run`, contract v1.7): `gamepilot checkpoints --from --to`
  sends every checkpoint's state and time, the mode and the current checkpoint's trial (2 of 3, 1
  pass) at the start and the end of each run (`Story.Chain_progress`). Each run has its own daemon,
  so the page's stream reconnects between runs and gets the chain again. The page shows it as a Run
  strip of chips above the plan and keeps each checkpoint's last plan in its own memory, so clicking
  a finished checkpoint shows its events at its end, with their times; the daemon keeps only the
  latest of each. For a grind the current event also shows the battle count and goal from the
  grind's log lines.
- **Each event carries its times** (`started_ms`, `ended_ms` in `watch.plan`, contract v1.8, Unix
  ms, stamped by the runner as each event starts and ends: `Wire.Watch.stamp`). The page shows each
  finished event's time, the current one's so far (right after a reload too: the time comes from
  the program, not from when the page connected) and the checkpoint's total, from its first start
  to now or to its last end (`Wire.Watch.event_ms`, `plan_ms`; the page's `eventMs`, `planMs`).
- **Stop goes back through the daemon**: it clears the queued commands and releases every button at
  once, then sends `stop` to the program. The session marks itself stopped, and the program's next
  wait on the game (`submit`, `race`, `await`) raises `Effects.Stop_requested`. Plain requests still
  work, so the runner's failure path saves `failure.png`/`failure.ss` and records
  `FAIL ... at #n event: stopped by user` with KEEP, as for any failure. The failure repeats, so
  a series stops too.

## Why this shape

- One process owns the pixels. A second reader of the capture card (OBS, another program) is not
  possible, and the daemon already decodes each frame for its probes.
- Frames are pulled, not pushed: the page asks for `/frame` after it drew the last one, and the
  daemon encodes at most one frame per 200 ms (the probed frame when it is current, so mGBA needs
  no extra bridge read) and only when asked, so without a page nothing is encoded. Probe overlays
  are sent at most every 200 ms and status once a second, only while a page has the stream open.
  A viewer that does not take an event within 100 ms is dropped, so a slow browser cannot stall
  lockstep pacing. The daemon's 10 s rate line adds the watch's own time.
- Small frames go out lossless: the GBA's 240x160 is a PNG (pixel art blurs in JPEG), a capture
  card's frame is scaled to 640x360 and sent as JPEG. The page shows the frame at a whole multiple
  that fits, pixelated, and the lockstep 10 s rate line gives the bytes per frame.
- The probe boxes are drawn on a canvas over the frame at the displayed size, never into the frame,
  so labels stay sharp. A program may subscribe 80+ probes, so the page shows only the boxes whose
  value changed in the last second by default (Off / Changed / All, kept in the browser), a label
  only for the box under the pointer (or tapped), and every value in a table beside the frame,
  filtered by name prefix (`party.`, `bag.`, ...).
- The wire log and replay stay as they are: the program's watch notes are never logged, and the
  replay handler drops them when the program sends them. Only `stop` is logged (it changes what
  the program does), so a stopped run replays to the same stop.
- Localhost by default. `--listen 0.0.0.0` (or `GAMEPILOT_WATCH_LISTEN=0.0.0.0`, which the mGBA
  script reads from `~/.config/gamepilot/env`) opens the page and the hub to the LAN. Watching is
  then open to anyone on the network, Stop is not: see Stop's token below.

## One page per run, and the hub

Two runs at once (mGBA and the Switch, later several mGBAs) must not share ports, and the user
wants one place to find them.

- **Free ports.** `gamepilot checkpoints` starts each daemon with `--port 0 --watch-port 0` unless
  the flags fix them: the daemon binds free ones and prints them, and the runner reads them from
  its output. The next run of the same series asks for the same two ports again (the last daemon
  has exited), so the page keeps its URL and its stream reconnects across checkpoints; when they
  are taken meanwhile it takes new ones and prints the new URL. The mGBA bridge port stays fixed
  (one mGBA today).
- **The registry.** While its page is up, each daemon keeps one file in `$GAMEPILOT_RUNS/.watch/`,
  `<pid>.json`: pid, the page's port and address, backend, run folder, checkpoint, start time
  (`daemon/src/watch_registry.*`). It removes it on exit; a daemon that died leaves a stale file,
  which every reader skips because its pid is gone.
- **The hub.** `gamepilot_daemon --hub` serves one page on the fixed port 47901
  (`daemon/src/watch_hub.*`, `watch/hub.html`, the same HTTP pieces, no new dependency): the live
  runs from the registry (`/runs.json`), each with its checkpoint, mode and trial from that run's
  `/summary.json` (its latest `watch.run` and `watch.plan`, fetched by the browser from the run's
  port), elapsed time and what it is doing, linking to the run's page. Links use the address the hub
  was opened with, so a LAN viewer gets LAN links. The runner starts the hub when nothing answers on
  47901, in a session of its own, so it outlives the run; a second one exits at once. `gamepilot
  runs` prints the same list in the terminal.
- **Stop's token.** `POST /stop` needs `?token=T`, one random token per series, which the runner
  passes to each daemon (`--watch-token`). The daemon puts it in the page it serves to a viewer on
  its own machine (the `gamepilot-token` meta tag), so local Stop works as before; a page served to
  another machine has none and shows "read-only" instead of Stop, unless its URL carries
  `?token=T`. With `--listen` beyond localhost the runner prints that URL, with the machine's LAN
  address, for the user's other device.

Not yet: a Start button, the hold lease and pad (Control-UI step 3), recorded runs and scrubbing.
