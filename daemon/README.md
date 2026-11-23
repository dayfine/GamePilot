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

`daemon/tools/smoke_client.py --state <file.ss>` drives a running daemon: load a state, subscribe a
`core.color_stats@1` box on the FireRed start menu, press Start, then B, and print the numbers.

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
| `src/net.*` | 127.0.0.1 TCP (POSIX and Winsock) |

`daemon/CMakeLists.txt` adds `third_party/Arduino-Source/SerialPrograms` as a subdirectory with
`PA_CORE_ONLY=ON`, which includes only upstream's `SourceFiles.cmake` and `CoreLib.cmake`.
CoreLib's own sockets are thread-and-listener based; the daemon's single-threaded poll loop uses the
small `net.*` layer instead.
