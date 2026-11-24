# Watch page (2026-11-23)

`gamepilot checkpoints ... --watch` opens a page for watching one run live, the same on mGBA and
the Switch, from any browser: the game frame with the subscribed probe boxes and their latest
results, the checkpoint's events (done, current, failed, skipped), the story log, the daemon's
health, and a Stop button. It is step 1 and part of step 2 of `Control-UI.md`.

## Data flow

```
                 frame, probes, status (the daemon has them)
 browser  <-- GET /events (Server-Sent Events) ---------------+
          <-- GET /frame.jpg (polled, <= 5/s) ----------------+-- daemon (server loop)
          --- POST /stop ------------------------------------>+      |  ^
                                                                    |  | watch.plan, watch.log
                                     stop (notification) ---------->+  | (notifications, not in
                                                                    v  |  wire.jsonl)
                                                         OCaml program (Live session)
```

- **The daemon serves the page** (`daemon/src/watch_server.*`, `server_watch.cpp`): a small HTTP
  server on its own port (`--watch-port`, default 47901), polled by the same loop as the program's
  socket, no thread of its own. It already holds the frame, the probes and the health; the page is
  one HTML/JS file (`daemon/watch/watch.html`) compiled in and served as is. No new dependency.
- **The program publishes what only it knows**: the plan's states and its story lines, as two
  notifications (`watch.plan`, `watch.log`, contract v1.6) sent through the `show_plan`/`show_log`
  effects. Notifications need no answer, so they cost the program nothing but a write. The daemon
  keeps the latest plan and the last 1000 lines for a page that connects later.
- **Stop goes back through the daemon**: it clears the queued commands and releases every button at
  once, then sends `stop` to the program. The session marks itself stopped, and the program's next
  wait on the game (`submit`, `race`, `await`) raises `Effects.Stop_requested`. Plain requests still
  work, so the runner's failure path saves `failure.png`/`failure.ss` and records
  `FAIL ... at #n event: stopped by user` with KEEP, as for any failure. The failure repeats, so
  a series stops too.

## Why this shape

- One process owns the pixels. A second reader of the capture card (OBS, another program) is not
  possible, and the daemon already decodes each frame for its probes.
- Frames are pulled, not pushed: the page asks for `/frame.jpg` after it drew the last one, and the
  daemon encodes at most one frame per 200 ms (the probed frame when it is current, so mGBA needs
  no extra bridge read) and only when asked, so without a page nothing is encoded. Probe overlays
  are sent at most every 200 ms and status once a second, only while a page has the stream open.
  A viewer that does not take an event within 100 ms is dropped, so a slow browser cannot stall
  lockstep pacing. The daemon's 10 s rate line adds the watch's own time.
- The wire log and replay stay as they are: the program's watch notes are never logged, and the
  replay handler drops them when the program sends them. Only `stop` is logged (it changes what
  the program does), so a stopped run replays to the same stop.
- Localhost by default. `--listen 0.0.0.0` opens the page to the LAN; both the daemon and the runner
  print that anyone who reaches it can press Stop.

Not yet: a Start button, the hold lease and pad (Control-UI step 3), recorded runs and scrubbing.
