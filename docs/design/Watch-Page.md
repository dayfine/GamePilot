# Watch page (2026-11-23)

`gamepilot checkpoints ... --watch` opens a page for watching one run live, the same on mGBA and
the Switch, from any browser: the game frame with the subscribed probe boxes and their latest
results, the chain of checkpoints the run goes through, the checkpoint's events (done, current,
failed, skipped), the story log, the daemon's health, and a Stop button. It is step 1 and part of step 2 of `Control-UI.md`.

## Data flow

```
                 frame, probes, status (the daemon has them)
 browser  <-- GET /events (Server-Sent Events) ---------------+
          <-- GET /stream (MJPEG, <= 30/s) -------------------+-- daemon (server loop;
          <-- GET /frame (fallback, polled, <= 5/s) ----------+    stream worker thread)
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
  pass) at the start and the end of each run (`Engine_series.Chain_progress`). Each run has its own daemon,
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
- **The frame is a live MJPEG stream** (`daemon/src/frame_stream.*`): `GET /stream` answers
  `multipart/x-mixed-replace`, and the page's `<img src="stream">` shows each part as it comes, up
  to 30 frames a second (`--stream-fps`). The frame loop only hands over the frame (shared, not
  copied: the probed frame when it is current, so mGBA needs no extra bridge read) at most that
  often and only while a viewer is connected; a worker thread of its own encodes it once per width
  the viewers asked for, shared by all of them, and sends it with non-blocking writes. A viewer
  still taking the last frame skips the new one: frames are dropped for a slow viewer, never
  queued, and one that takes nothing for 10 s is dropped. Without a viewer nothing is read or
  encoded. The worker prints a 10 s line while a viewer is connected (encodes/s, ms and bytes per
  frame, the slowest viewer's frames/s). WebRTC would carry video better but needs new
  dependencies; MJPEG needs none, and every browser shows it in an `<img>`.
- When the stream fails the page polls `/frame` instead (at most one frame per 200 ms, PNG or JPEG
  as before) and tries the stream again after 15 s; it opens it again for each new daemon (its
  `info` event) and closes it while the tab is hidden. Probe overlays
  are sent at most every 200 ms and status once a second, only while a page has the event stream open.
  A viewer that does not take an event within 100 ms is dropped, so a slow browser cannot stall
  lockstep pacing. The daemon's 10 s rate line adds the watch's own time.
- MJPEG cannot carry PNG, so a GBA frame (240x160) is doubled with nearest-neighbour pixels and
  sent as JPEG at quality 90 with full colour resolution (4:4:4): each game pixel covers 2x2
  pixels, JPEG's 8x8 blocks hold whole game pixels, and text edges stay clean (1x at quality 95
  rang around letters; 3x and 4x cost twice the bytes for no visible gain). A capture card's
  frame is scaled to 1280x720 (`--stream-width`; the page asks for 960 with `?w=960` on a
  window narrower than 700 px) at quality 80: bilinear, since area averaging cost 6 ms of CPU a
  frame at 1080p to 720p and looks the same on game screens (a whole factor, 1080p to 960, still
  averages). `/frame` still sends a GBA frame as PNG and a capture card's at 640x360.
- The page sizes the frame from the backend's frame size (`info`), not from the image received,
  so the frame keeps its size whether it comes from the stream (scaled) or `/frame`, and the probe
  canvas sits on it at any size: a GBA frame at a whole multiple that fits, pixelated (the doubled
  image stays sharp at every multiple), a capture card's at the fraction that fits.

  Measured on the lab Mac, Switch backend replaying a clip (60 fps H.264, 4 probes
  subscribed), one daemon at a time, 30 s per row, process CPU from `ps`; fps is what each viewer
  received (curl, or headless Chrome on the page):

  | clip | viewers | encode ms/frame | bytes/frame | per viewer | daemon CPU | fps |
  |---|---|---|---|---|---|---|
  | 1920x1080 | 0 | - | - | - | 23% | - |
  | 1920x1080 | 1 (1280 wide) | 1.6 | 115 KB | 3.4 MB/s | 37% | 30.3 |
  | 1920x1080 | 3 (1280 wide) | 1.6 | 115 KB | 3.4 MB/s | 35% | 30.3 |
  | 1920x1080 | 1 (960 wide) | 1.0 | 76 KB | 2.3 MB/s | 23-30% | 30.3 |
  | 1920x1080 | Chrome, desktop / phone | 1.5 / 1.0 | 115 / 76 KB | | | 30.2 / 30.3 |
  | 240x160 | 0 | - | - | - | 2% | - |
  | 240x160 | 1 | 0.6 | 50 KB | 1.5 MB/s | 10% | 30.5 |
  | 240x160 | 3 | 0.6 | 50 KB | 1.4 MB/s | 10% | 30.5 |
  | 240x160 | Chrome | 0.6 | 48 KB | | | 30.5 |

  The baseline is the replay's video decoding and the probes. Three viewers cost what one does:
  the frame is encoded once.
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
  `/summary.json` (its latest `watch.run` and `watch.plan`), elapsed time and what it is doing,
  and the latest finished runs from `RESULTS.tsv` beside the registry (`/recent.json`). The runner
  starts the hub when nothing answers on 47901, in a session of its own, so it outlives the run; a
  second one exits at once. `gamepilot runs` prints the same list in the terminal.
- **Stable URLs.** The hub serves each live run's page under the run folder's name, on its own
  port, so a URL can be read, typed and bookmarked:

  | URL | what it is |
  |---|---|
  | `http://HOST:47901/` | all runs: live, then recent finished ones |
  | `http://HOST:47901/runs/2026-11-23-mg-07-testing-1/` | that run's page (`?token=T` for Stop from another device) |
  | `http://HOST:47901/live` | redirects to the newest live run (keeps `?token=`) |
  | `http://HOST:47901/live/mg-07` | the newest live run of checkpoint mg-07 |

  `/live` with no live run shows a page that looks again every 5 s, so a bookmark of it waits for
  the next run. A run that is not live any more answers "has ended or not started yet". The runner
  prints the `/live` URL beside the hub's.
- **The hub passes a run through.** Everything under `/runs/NAME/` (the page, `events`, `stream`,
  `frame`, `summary.json`, `POST stop`) goes to the run's port on loopback with a head the hub
  writes itself, and the answer streams back as it comes, read 64 KB at a time and written as soon
  as the browser takes it: the event stream and the MJPEG stream are not buffered. The run's
  socket is not read while 256 KB wait for the browser, so a slow browser makes the run drop
  frames for it, as a slow direct viewer does. The run's own port keeps working as before.

  Measured on the lab Mac with two Switch replay daemons (1920x1080 60 fps clip, 1280 wide
  stream) and the hub, 30 s per row:

  | viewer | fps | MB/s | daemon CPU | hub CPU |
  |---|---|---|---|---|
  | curl on the run's port | 30.6 | 3.53 | 22-49% | - |
  | curl through the hub | 30.4 | 3.52 | 22-43% | 0.04 s in 30 s (0.13%) |
  | Chrome through the hub (desktop page) | 30.4 | 3.5 | | 0.04 s in 27 s |
- **The runs sidebar.** Every run page has a sidebar (the ☰ button): live runs first, newest
  first, with checkpoint, backend, elapsed time and state, then the latest finished runs (pass or
  fail, when, where it failed; the reason on hover), the current run highlighted. It polls the hub's
  `runs.json` and `recent.json` every 3 s while the tab is visible. A finished run links to its
  record (Past runs, below). On a wide window it is a column beside the
  page, open unless closed (kept in the browser); on a phone it is a drawer over the page, closed
  until opened, so the frame keeps its place. Its rows have fixed heights, and the page's layout
  does not depend on it, so updates move nothing (#65/#70). Opened on the run's own port, the
  page asks the hub on port 47901 (`?hub=N` for another), which answers `runs.json` and
  `recent.json` to any origin; without a hub the sidebar says "Hub not running".
- **When a run ends.** When the page's run leaves the registry, a notice at the bottom (fixed, so
  nothing moves) says it ended, with its result from `RESULTS.tsv` when it is there, and links to
  its record and to `/live`. The page stops fetching its frame and hides Stop. The next checkpoint of a series takes
  the run's port again: a page opened through the hub follows it to its new `/runs/NAME/`; one
  opened on the port reconnects as before.
- **Stop's token.** `POST /stop` needs `?token=T`, one random token per series, which the runner
  passes to each daemon (`--watch-token`). The daemon puts it in the page it serves to a viewer on
  its own machine (the `gamepilot-token` meta tag), so local Stop works as before. Through the hub
  the run sees the hub's loopback connection, so the hub adds `X-GamePilot-Viewer: remote` for a
  browser on another machine and the run leaves the token out (the hub writes every head it passes
  on, so a browser cannot set or drop that header); a page served to
  another machine has none and shows "read-only" instead of Stop, unless its URL carries
  `?token=T`. With `--listen` beyond localhost the runner prints that URL, with the machine's LAN
  address, for the user's other device.

## The hub serves the page

Through the hub, `/runs/NAME/` is the hub's own build of `watch.html`, never the run daemon's:
the run supplies only data (`events`, `stream`, `frame`, `summary.json`, `POST stop`), which the
hub passes through as before. So every page shows the newest UI, however old the daemon that runs
it, and an old daemon keeps working through a new hub (its data endpoints are the same). Stop's
token still comes from the run: for a browser on this machine the hub asks the run for its page
(as the run's own local viewer, the way any old daemon answers), reads the token from its meta
tag, and sends its own page with that token in place of the run's; for a browser on another
machine it sends its page without one, as the run would. The run's own port still serves the
run's own copy.

## Runs list

The hub's `/` lists the live runs (as before), then every run folder in `$GAMEPILOT_RUNS`
(`GET /history.json`, `daemon/src/run_history.*`), newest first by default: run (linked to its
page), game, program (their registry names, the ids on hover), checkpoints (the series' `from → to`, this run's own in bold), backend (mGBA,
Switch), mode, result (failed at where, the reason under the name and on hover), start time,
duration; a "frames" tag on a recorded run.

- **Where it comes from.** The runner writes `run.json` in each run folder at the start (run,
  game, `game_name`, program, `program_name`, group, from, to, checkpoint, backend, mode,
  `started_ms`) and again at the end with `ended_ms`, result, at and reason
  (`src/bin/run_record.ml`). The program is the registry's whose checkpoints folder the plan
  folder is (`src/program_registry`, `docs/programs/README.md`): `game` and `program` are its ids
  (`frlg`, `frlg.mail_glitch`), the others its names and group path (`FRLG / Glitches`). A folder
  from before `run.json` falls back to its name (`<date>-<checkpoint>-<mode>-<n>`), its
  `RESULTS.tsv` row (result, reason, end time), its daemon's first output line (backend) and its
  wire log's last `t_ms` (how long it ran, so its start); game and program are unknown there,
  since the daemon knows no game names, until `gamepilot runs --backfill --apply` writes a
  `run.json` naming the program that has a plan for the folder's checkpoint (only the program
  fields, so the rest still comes from the fallbacks; never in a folder that has one).
- **Sort**: a click on a column's header sorts by it, a second click reverses. Text columns start
  A to Z, Started and Duration newest and longest first; unknown values go last either way, and
  ties go newest first. The default is Started, newest first.
- **Group by program**: the toggle puts each program's runs under a heading (its name, group,
  id and run count), the programs by name, unknown last, the sort inside each.
- **Filters**: game, program, backend, mode, result (each a list of the values the runs have;
  game and program by their names, from `run.json`: the hub reads them there rather than from a
  copy of the registry built into the daemon, which knows no games, and a program with no run has
  nothing to filter),
  a date range (since, until, local days) and a search over the run name and failure reason. They
  live in the URL's query, so a filtered list is a bookmark:

  | URL | shows |
  |---|---|
  | `/?backend=switch&result=fail` | failed Switch runs |
  | `/?program=frlg.mail_glitch&mode=verification` | the program's verification runs |
  | `/?sort=duration&dir=desc&group=program` | each program's runs, longest first |
  | `/?since=2026-11-23&q=no_text` | runs since that day whose name or reason has `no_text` |

  The keys are `game`, `program`, `backend`, `mode`, `result` (`pass`, `fail`, `running`,
  `(unknown)`), `since`, `until` (`yyyy-mm-dd`), `q`, `sort` (`run`, `game`, `program`,
  `checkpoint`, `backend`, `mode`, `result`, `start`, `duration`), `dir` (`asc`, `desc`) and
  `group` (`program`). The list is polled every 5 s while the tab
  is visible; reading the folder takes about 10 ms for 90 runs.

## Past runs

`/runs/NAME/` for a run that is not live is its record (`watch/run.html`, from the hub's build):
the result, where and why it failed, game, program, range, backend, mode, start and duration;
`failure.png`; the plan with each event's time; the full story log; the recorded frames with a
scrubber; and the probe values over the run. Everything is read from the run folder through the
hub (`record.json`, `probes.json`, `files/PATH`); the hub serves only the folder's notes, log,
failure frame and recorded frames, never `wire.jsonl` as it is.

- **What the daemon keeps.** The program's notes never reach the wire log, so the daemon keeps
  them in the run folder itself (`--run-folder`, which the runner now always passes;
  `daemon/src/run_journal.*`): `watch_plan.json` (the latest plan, each event with its times),
  `watch_run.json` (the chain), `watch_log.jsonl` (each story line with its Unix time) and
  `daemon.json` (backend, the Unix time of the daemon clock's 0, recording and keep-awake). A
  run from before them has its plan rebuilt from `story.log`'s `[Story]` lines, without times.
- **One time for everything.** Frames, story lines and events carry Unix ms; the wire log's
  `t_ms` is the daemon's clock, put on the same time by `daemon.json`. The scrubber moves one
  time through all of them: the recorded frame at it, the story line at it (and the two before),
  each probe's value at it, a cursor on every probe's line, the event it is in. Clicking an event,
  a log line or a probe's line jumps there; ◀/▶ (and the arrow keys) step frames, "step" jumps
  between events, "failure" to the failure frame. `?t=S` opens the page S seconds in; without it
  the page opens at the failure, else the end.
- **Probe timeline.** `wire.jsonl` reaches 70 MB, so the page never loads it: the hub reads it a
  1 MB chunk at a time (parsing only frame lines that carry results), turns each result into one
  number (color_stats: the mean of its channel means; color_count: fraction; template_match:
  score), keeps each probe's last value per second and only when it changed, and sends that
  (`probes.json`). It keeps the last 8 in memory while the file keeps its size. Measured on the
  lab Mac: a 68 MB, 76632-line mGBA log takes 0.6 s the first time, under 10 ms after, and gives
  about 1 MB of JSON for its 3275 probes (most of them template matches that ran once). The page
  shows the 60 busiest probes that match its filter (`party.`, `dialog.`). It reads
  `wire.jsonl.gz` the same way (miniz, which CoreLib builds) once the disk cleanup packed the log,
  and keeps to the program's connection (the one that spoke first): another client's frames, such
  as a `gamepilot ctl read`, are left out.

## Recording

On the Switch backend the daemon records the run (`--record`, the default there; `--no-record`;
off on mGBA unless `--record`, whose runs replay from save states): a 640-wide JPEG every second,
plus one at each new event of the plan (`step`) and one at a failure (the plan's failed event or
the `backend.save_frame` the runner makes for `failure.png`, once), into the run folder's
`frames/`, with `frames/index.jsonl` (file, seq, daemon and Unix time, the event, why). It rides
the live stream's worker thread (`frame_stream.h`): the frame loop only hands the frame over when
one is due, as for a viewer, and the worker encodes it with the stream's encoder and writes it;
without a watch page the daemon starts the same worker for recording alone. Between two events
(none current) the frames stay with the last one. The worker prints a line a minute: frames, ms
and bytes each, MB per hour.

Measured on the lab Mac, Switch backend replaying the 1920x1080 60 fps clip, a client
subscribing 6 probes and pressing twice a second for 43 s, one daemon at a time, twice each:

| recording | daemon CPU in 43 s | frames probed and sent | encode + write per frame | bytes per frame | disk |
|---|---|---|---|---|---|
| off | 11.6 s, 12.0 s | 2495, 2496 | - | - | - |
| on | 12.4 s, 12.3 s | 2499, 2500 | 1.1-1.4 ms (worker thread) | 40-41 KB | 146-167 MB/hour |

Recording costs under 2% of a core and nothing on the frame loop: the program got as many probed
frames either way. A GBA frame (mGBA with `--record`) is doubled to 480x320, about 50 KB.

Disk: about 150 MB an hour of Switch run. `~/BDSPLab/disk_gc.sh` handles run folders by age (a
folder untouched for 14 days goes unless it holds KEEP, which every failing run does) and gzips
`wire.jsonl` once it is older than a day; it leaves `frames/index.jsonl` and `watch_log.jsonl`
plain, since the past-run page reads them as they are. The probe timeline reads the gzipped wire
log. `projects-gc` does not look at the runs folder.

## Keep-awake

A Switch daemon presses B after 180 s with no input (`--keepawake SECONDS`, 0 = off; mGBA:
off; `--keepawake-key`), only while no client batch is queued or running, no client holds the input
lease and no client submitted in that window, as a batch of its own whose `batch_done` goes to no client
(`daemon/src/keep_awake.*`). Each press is a `daemon` line in the wire log
(`protocol/v1/34-keepawake.line.json`), which replay skips. It replaces
`~/BDSPLab/gp_keepawake.py`, which the old one-client rule locked out (`docs/switch-bring-up.md`).

## Input lease

Any number of clients may connect to a daemon (contracts v1.9): a program, `gamepilot status`,
`gamepilot ctl`. Reads are served to all of them; input (`submit`, `cancel`,
`backend.load_state`) needs the input lease, which one connection holds at a time
(`daemon/src/input_lease.*`). The health panel shows the holder: its owner (and client name when
that differs) and since when it has held it, or "free"; and how many clients are connected.
`gamepilot ctl` (`docs/switch-bring-up.md`) is how a person or a script drives by hand meanwhile.

Not yet: a Start button and the pad on the page (Control-UI step 3).
