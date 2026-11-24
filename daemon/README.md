C++ daemon: one backend (frame source, input sink, frame clock), probes on OpenCV, and the v1
JSON-RPC server (`contracts/v1`). `CoreLib` (from `third_party/Arduino-Source`, through its own
cmake files) provides JSON and file I/O; it builds on Linux, macOS and Windows.

    cmake -S daemon -B daemon/build -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
    cmake --build daemon/build -j4
    ctest --test-dir daemon/build --output-on-failure

Run it against an mGBA instance with the MgbaLink bridge (`lab/mgba/bridge.lua`, paced mode):

    daemon/build/gamepilot_daemon --backend mgba --mgba-port 47810 [--port 47900] [--log wire.jsonl] [--fast]

The daemon holds the emulator in lockstep: before each frame it sends the frame's keys
(`KEYS <seq> <mask>`), grants exactly one frame (`GRANT <seq+1>`), waits for it, and, while a probe is
subscribed, reads that frame (`FRAME`) and sends one `frame` notification for it. Frames are paced to
the backend's rate (59.7275 fps on the GBA); `--fast` steps as fast as the emulator goes. Everything
runs on one thread: the client is served between frames.

## The Switch backend

    daemon/build/gamepilot_daemon --backend switch (--replay clip.avi | --capture DEVICE) \
        [--viewport x,y,w,h] [--port 47900] [--log wire.jsonl]

Live, not lockstep (a capture card cannot be paused): a capture thread reads frames at the source's
rate, stamps each with a `seq` and the daemon clock, and pushes it into a bounded ring; the server
thread probes each frame from the ring and hands timed key segments to the controller when they are
due. A full ring drops its oldest frame, which the server counts as a gap. `--replay` plays a recorded
video at its own frame rate; `--capture` opens a capture card through OpenCV (index or name; 1920x1080
at 60 fps requested). The controller speaks CoreLib's PABotBase2 wire format (a wired controller state
per press, in CoreLib-built packets), but for now to `FakeSwitch`, a fake board that acks every
packet: the real board needs the session handshake first.

`status` (contracts v1.5) reports each thread's heartbeat, the ring, gaps, the client and the
fidelity, also to a second connection while a program is connected; `gamepilot status` prints it and
marks a thread stuck when its heartbeat is over 2 s old.

`press_latency --fake [--response-ms 50] [--fps 60] [--presses 20]` is the latency harness: it
presses a button and times the first captured frame that changes. On `FakeSwitch` the screen turns
bright `response-ms` after a press starts, so it should report that plus up to one frame.

`daemon/tools/smoke_client.py --state <file.ss>` drives a running daemon: load a state, subscribe a
`core.color_stats@1` box on the FireRed start menu, press Start, then B, and print the numbers.

## The watch page

    gamepilot_daemon ... [--watch-port 47901] [--listen 127.0.0.1]

Either flag turns on the watch page (`docs/design/Watch-Page.md`): `http://127.0.0.1:47901/` shows
the frame (a downscaled JPEG, at most 5 per second, only while a page asks) with the subscribed probe
boxes and their results, the program's plan and log (`watch.plan`, `watch.log`, contracts v1.6) and
its chain of checkpoints (`watch.run`, v1.7), the `status` health (a heartbeat over 2 s old is red), and Stop: it releases every button and sends
the program `stop`. `--listen 0.0.0.0` opens it to the network, which the daemon says when it starts.
The page is `watch/watch.html`, compiled in. The 10 s rate line on mGBA adds what the page costs
(frames sent, ms spent). `gamepilot checkpoints --watch` starts the runner's daemons with it.

## Probing saved images

`probe_images` runs the same probes on PNG files, with no backend and no socket, so readers can be
built and tested from saved screenshots (mGBA shots, CommandLineTests images):

    daemon/build/probe_images --spec probes.json [--viewport x,y,w,h] [--game-size WxH] \
        shot1.png [shot2.png ...] > results.jsonl

The spec file is the `subscribe` params (`{"probes": [...]}`, `contracts/v1`); a
`core.template_match@1` probe's `template` is a PNG path, relative to the spec file, instead of an
uploaded hash. Each image gives one line `{"image": path, "probes": {id: result}}`, the `probes` of a
`frame` notification. Boxes are relative to the game picture and templates are in game pixels, as on
the wire; `--viewport` says where the picture sits in every image (default the whole image, as on
mGBA; for a Switch capture of FRLG, the fork's `GAME_BOX`: `0.09375,0.00462963,0.8125,0.962963`) and
`--game-size` its native size (default `240x160`, the GBA). A scaled template must fit its box at each
image's size, or the tool stops with an error. `tests/probe_images/` is a worked example: the same
picture whole and at 2x inside side bars give the same results.

| File | Role |
|---|---|
| `src/backend.h` | the I/O boundary |
| `src/mgba_backend.*` | mGBA through the bridge's line protocol |
| `src/probes.*` | probe kinds (`core.color_stats@1`, `core.template_match@1` with its optional ink masks, `core.color_count@1`) on frame pixels |
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
| `src/watch_server.*` | the watch page's server: page, frame, event stream, Stop |
| `src/server_watch.cpp` | what the server shows there, the program's notes, Stop |
| `watch/watch.html` | the page (compiled in by `cmake/embed_watch_page.cmake`) |
| `src/switch_backend.*` | the Switch: capture thread, ring reader, controller |
| `src/video_capture.*` | frame sources: capture card and video replay (OpenCV `VideoCapture`) |
| `src/frame_ring.*` | the bounded ring between the capture and server threads |
| `src/switch_controller.*` | GBA keys to wired controller states, sent in CoreLib's PABotBase2 packets |
| `src/live_schedule.*` | command batches to key segments in wall time (live backends) |
| `src/fake_switch.*` | a fake controller board and screen, for tests, the harness and console-free runs |
| `src/press_latency*` | the latency harness and its `press_latency` command |

`daemon/CMakeLists.txt` adds `third_party/Arduino-Source/SerialPrograms` as a subdirectory with
`PA_CORE_ONLY=ON`, which includes only upstream's `SourceFiles.cmake` and `CoreLib.cmake`.
CoreLib's own sockets are thread-and-listener based; the daemon's single-threaded poll loop uses the
small `net.*` layer instead.
