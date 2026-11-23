C++ daemon: one backend (frame source, input sink, frame clock), probes on OpenCV, and the v1
JSON-RPC server (`contracts/v1`). `CoreLib` (from `third_party/Arduino-Source`, through its own
cmake files) provides JSON and file I/O; Qt-free on Linux, macOS and Windows.

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

| File | Role |
|---|---|
| `src/backend.h` | the I/O boundary |
| `src/mgba_backend.*` | mGBA through the bridge's line protocol |
| `src/probes.*` | probe kinds (`core.color_stats@1`) |
| `src/schedule.*` | command batches to key masks on exact frames |
| `src/rpc.*` | v1 messages to and from structs |
| `src/server.*` | the JSON-RPC server and the frame loop |
| `src/net.*` | 127.0.0.1 TCP (POSIX and Winsock) |

`daemon/CMakeLists.txt` adds `third_party/Arduino-Source/SerialPrograms` as a subdirectory with
`PA_CORE_ONLY=ON`, which includes only upstream's `SourceFiles.cmake` and `CoreLib.cmake`.
CoreLib's own sockets are thread-and-listener based; the daemon's single-threaded poll loop uses the
small `net.*` layer instead.
