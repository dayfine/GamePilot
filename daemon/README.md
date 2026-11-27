C++ daemon: one backend (frame source, input sink, frame clock), probes on OpenCV, and the v1
JSON-RPC server (`protocol/v1`). `CoreLib` (from `third_party/Arduino-Source`, through its own
cmake files) provides JSON and file I/O; it builds on Linux, macOS and Windows.

    cmake -S daemon -B daemon/build -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
    cmake --build daemon/build -j4
    ctest --test-dir daemon/build --output-on-failure

Run it against an mGBA instance with the MgbaLink bridge (`lab/mgba/bridge.lua`, paced mode):

    daemon/build/gamepilot_daemon --backend mgba --mgba-port 47810 [--port 47900] [--log wire.jsonl] [--fast | --speed S]

The daemon holds the emulator in lockstep: before each frame it sends the frame's keys
(`KEYS <seq> <mask>`), grants exactly one frame (`GRANT <seq+1>`), waits for it, and, while a probe is
subscribed, reads that frame (`FRAME`) and sends one `frame` notification for it. Frames are paced to
the backend's rate (59.7275 fps on the GBA); `--speed S` paces them at S times that rate, and
`--fast` steps as fast as the emulator goes (mGBA must not throttle itself for either: audio and video
sync off, as `run/run_checkpoints_on_mgba.sh --speed S` starts it). Presses and waits are whole
frames, and a `frame`'s or `batch_done`'s `t_ms` is game time (contracts v1.10), so a program's
timing means the same at any speed. Everything
runs on one thread (the client is served between frames) except the watch page's stream encoder.

## The Switch backend

    daemon/build/gamepilot_daemon --backend switch (--replay clip.avi | --capture INDEX) \
        [--serial PORT] [--viewport nso-gba|native|x,y,w,h] [--port 47900] [--log wire.jsonl]
    daemon/build/gamepilot_daemon --backend switch --serial PORT --board-check
    daemon/build/gamepilot_daemon --backend switch --capture INDEX --capture-check frame.png

Live, not lockstep (a capture card cannot be paused): a capture thread reads frames at the source's
rate, stamps each with a `seq` and the daemon clock, and pushes it into a bounded ring; the server
thread probes each frame from the ring and hands timed key segments to the controller when they are
due. A full ring drops its oldest frame, which the server counts as a gap. `--replay` plays a recorded
video at its own frame rate; `--capture` opens a capture card through OpenCV (by index; 1920x1080 at
60 fps requested). `--viewport` says where the game picture sits (`src/viewport.h`). `nso-gba`, the
default, is the GBA picture in the Switch's GBA app (`nso_gba_viewport()`, FRLG), checked on the
lab's captures. `native` is a full-screen Switch game (`native_switch_viewport()`): the whole frame,
in 1920x1080 game pixels, so a probe box is a fraction of the frame as the fork's `ImageFloatBox` is
and a 1080p template is matched at its own size. `x,y,w,h` moves the picture box and keeps the
default's game size. `hello` reports both the picture box (`viewport`) and the game size.

Inputs go to the PABotBase2 board on `--serial` (`src/board_session.h`): the session starts as the C++
app starts it (DTR/RTS, the baud scan with resets, the link's version, packet size and buffer slots,
then the board's queries), checks the board already runs NS1 Wired Pro Controller (the lab app's
mode; it fails otherwise and never changes the mode), sends each state as a Pro Controller report
through the board's command queue and asks its status once a second. Without `--serial` they go to `FakeSwitch`, a fake board that answers the same handshake.
`--board-check` only starts the session (checking the mode) and prints what the board said; `--capture-check` saves one
frame and checks the picture's geometry. First session on the console: `docs/switch-bring-up.md`.

`status` (contracts v1.5) reports each thread's heartbeat, the ring, gaps, the client and the
fidelity, also to a second connection while a program is connected; `gamepilot status` prints it and
marks a thread stuck when its heartbeat is over 2 s old.

`press_latency --fake [--response-ms 50] [--fps 60] [--presses 20]` is the latency harness: it
presses a button and times the first captured frame that changes. On `FakeSwitch` the screen turns
bright `response-ms` after a press starts, so it should report that plus up to one frame.
`press_latency --serial PORT --capture INDEX` runs it on the console (100 Start presses in the FRLG
overworld) and passes when nothing is missed and p99 - median is under 50 ms.

`daemon/tools/smoke_client.py --state <file.ss>` drives a running daemon: load a state, subscribe a
`core.color_stats@1` box on the FireRed start menu, press Start, then B, and print the numbers.

## The watch page

    gamepilot_daemon ... [--watch-port 47901] [--listen 127.0.0.1] [--watch-token T]
        [--registry DIR] [--checkpoint ID] [--run-folder DIR] [--stream-fps 30] [--stream-width 1280]
    gamepilot_daemon --hub --registry DIR [--watch-port 47901] [--listen 127.0.0.1]

Either of the first two flags turns on the watch page (`docs/design/Watch-Page.md`): `http://127.0.0.1:47901/` shows
the live frame (an MJPEG stream, `/stream`, at most 30 frames a second, `--stream-fps`; a capture
card's frame scaled to 1280 wide, `--stream-width`; encoded on a thread of its own and only while a
viewer is connected; `/frame`, polled, when the stream fails) with the subscribed probe
boxes and their results, the program's plan and log (`watch.plan`, `watch.log`, contracts v1.6) and
its chain of checkpoints (`watch.run`, v1.7), the `status` health (a heartbeat over 2 s old is red;
the input lease's holder), and Stop: it releases every button and sends every client `stop`. `--listen 0.0.0.0` opens it to the network, which the daemon says when it starts.
Port 0 (for `--watch-port` and `--port`) binds a free port; the daemon prints both before its
"listening" line. Stop takes the token (`--watch-token`, else a random one): the page served to
this machine carries it, another machine's viewer needs `?token=` in the URL. With `--registry` the
daemon lists its page there (`<pid>.json`, removed on exit) for the hub: `--hub` proxies
live and finished run pages and redirects `/` to the Control Hub (`:47902`), exiting at once when its port is taken.
The page is `watch/page/watch.html` with its scripts and style beside it (`watch_*.js`, `watch.css`),
compiled in. The 10 s rate line on mGBA adds what the page costs
the frame loop (stream viewers, frames polled, ms spent); the stream prints its own 10 s line
(encodes/s, ms and bytes a frame, the slowest viewer's frames/s). `gamepilot run --watch` starts the runner's daemons with it.

## View-only sources

    gamepilot_daemon --backend view --window-pid PID [--window-title T] [--crop auto | --crop x,y,w,h] \
        [--stale-s 10] [--name NAME] [--source LABEL] [--tail-log FILE] --watch-port 0 --registry DIR
    gamepilot_daemon --backend view --window-app /Applications/X/X.app ...
    gamepilot_daemon --backend view --replay clip.mp4 ...

Shows another program's picture on the watch page with nothing sent anywhere (`src/view_backend.h`):
no controller, no lease, no keep-awake; `submit`, `cancel`, `backend.load_state`, `backend.reset`
and `lease.acquire` answer -32002 (`protocol/v1/41-error.view_only.response.json`). On macOS the frames
come from one app window through ScreenCaptureKit (`src/window_capture_mac.mm`; the terminal that
starts it needs Screen Recording), at most 30 a second; other platforms build without it. `--crop
auto` finds the video in the window (its edges, or the 16:9 area whose pixels change) and shows the
whole window until it does; `--crop` takes a box of the window. Once a second the page and
`/summary.json` get the picture's `source` state: `live`, `stale` (unchanged for `--stale-s`) or
`covered` (no part of the window shows, so its app stops painting it; a strip is enough). `--name`
lists it in the hub as `/runs/NAME/` under Watching (`/live` skips it); `--tail-log` follows the
other program's log, read only, into the page's log.

## Probing saved images

`probe_images` runs the same probes on PNG files, with no backend and no socket, so readers can be
built and tested from saved screenshots (mGBA shots, CommandLineTests images):

    daemon/build/probe_images --spec probes.json [--viewport x,y,w,h|nso-gba|native] [--game-size WxH] \
        shot1.png [shot2.png ...] > results.jsonl

The spec file is the `subscribe` params (`{"probes": [...]}`, `protocol/v1`); a
`core.template_match@1` probe's `template` is a PNG path, relative to the spec file, instead of an
uploaded hash. Each image gives one line `{"image": path, "probes": {id: result}}`, the `probes` of a
`frame` notification. Boxes are relative to the game picture and templates are in game pixels, as on
the wire; `--viewport` says where the picture sits in every image (default the whole image, as on
mGBA; for a Switch capture of FRLG, `nso-gba`, the fork's `GAME_BOX`; for a full-screen Switch game,
`native`, the whole image in 1920x1080 game pixels) and `--game-size` its native size (default
`240x160`, the GBA; a viewport name sets it too, so a `--game-size` goes after the name). A scaled template must fit its box at each
image's size, or the tool stops with an error. `tests/probe_images/` is a worked example: the same
picture whole and at 2x inside side bars give the same results.

| File | Role |
|---|---|
| `src/backend.h` | the I/O boundary |
| `src/mgba_backend.*` | mGBA through the bridge's line protocol |
| `src/probes.*` | probe kinds (`core.color_stats@1`, `core.template_match@1` with its optional ink masks, `core.color_count@1`, `core.line_shares@1`) on frame pixels |
| `src/blob_find.*` | `core.find@1`: colour filter, 4-connected blobs, size filter, stray share, template score, shape overlap |
| `src/viewport.*` | where the game picture sits in the frame: picture boxes to frame pixels, template scale |
| `src/probe_evaluation.*` | maps a subscribed probe onto the frame and runs it (daemon and `probe_images`) |
| `src/probe_images.cpp` | the offline `probe_images` tool |
| `src/template_store.*` | uploaded templates, decoded and keyed by the SHA-256 of their PNG bytes |
| `src/base64.*` | base64 decoding for template uploads |
| `src/schedule.*` | command batches to key masks on exact frames |
| `src/rpc.*` | v1 messages to and from structs |
| `src/server.*` | the JSON-RPC server and the frame loop |
| `src/net.*` | TCP (POSIX and Winsock): 127.0.0.1 for programs, any address for the page |
| `src/http.*` | the HTTP/1.1 and Server-Sent Events framing the watch page needs |
| `watch/server/watch_server.*` | the watch page's server: page, frame, event stream, Stop |
| `watch/server/server_watch.cpp` | what the server shows there, the program's notes, Stop |
| `watch/page/watch.html` | the page (compiled in by `cmake/embed_watch_page.cmake`) |
| `watch/page/*.js`, `watch/page/*.css` | the pages' scripts and styles, one file per job (compiled in by `cmake/embed_watch_assets.cmake`) |
| `watch/server/watch_assets.h` | those scripts and styles by name, served beside the page that loads them |
| `src/switch_backend.*` | the Switch: capture thread, ring reader, controller |
| `src/video_capture.*` | frame sources: capture card and video replay (OpenCV `VideoCapture`) |
| `src/view_backend.*` | the view-only backend: a source's frames, cropped, with no input |
| `src/view_source.*` | the picture's state (live, stale, covered) and where the video sits in a window |
| `src/window_capture*` | one app window as a frame source (ScreenCaptureKit on macOS) |
| `src/log_tail.*` | another program's log, followed for the page |
| `src/frame_ring.*` | the bounded ring between the capture and server threads |
| `src/switch_controller.*` | keys and stick tilts to Pro Controller reports (CoreLib's PABotBase2 message) |
| `src/board_session.*` | the board's session as the C++ app starts it, on CoreLib's link and device handle |
| `src/switch_geometry.*` | whether a capture shows the GBA picture where the viewport says |
| `src/live_schedule.*` | command batches to key segments in wall time (live backends) |
| `src/fake_switch.*` | a fake controller board and screen, for tests, the harness and console-free runs |
| `src/press_latency*` | the latency harness and its `press_latency` command |

`daemon/CMakeLists.txt` adds `third_party/Arduino-Source/SerialPrograms` as a subdirectory with
`PA_CORE_ONLY=ON`, which includes only upstream's `SourceFiles.cmake` and `CoreLib.cmake`.
CoreLib's own sockets are thread-and-listener based; the daemon's single-threaded poll loop uses the
small `net.*` layer instead.
