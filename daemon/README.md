C++ daemon. Built by the Week 0 link spike: `CoreLib` (from `third_party/Arduino-Source` via its own
cmake files) plus OpenCV, Qt-free, on Linux, macOS and Windows.

    cmake -S daemon -B daemon/build -G Ninja -DCMAKE_BUILD_TYPE=Release
    cmake --build daemon/build -j4
    daemon/build/gamepilot_daemon

`daemon/CMakeLists.txt` adds `third_party/Arduino-Source/SerialPrograms` as a subdirectory with
`PA_CORE_ONLY=ON`, which includes only upstream's `SourceFiles.cmake` and `CoreLib.cmake`.
