cmake_minimum_required(VERSION 3.25)
project(GamePilotDaemon LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Compile through ccache when it is installed and no launcher was given. base_dir
# is the repo root, so worktrees share cache entries. Arduino-Source's own
# PA_USE_CCACHE is forced off below: it would conflict with this launcher.
if(NOT CMAKE_CXX_COMPILER_LAUNCHER AND NOT MSVC)
  find_program(GAMEPILOT_CCACHE ccache)
  if(GAMEPILOT_CCACHE)
    cmake_path(GET CMAKE_CURRENT_SOURCE_DIR PARENT_PATH _gamepilot_root)
    execute_process(COMMAND "${GAMEPILOT_CCACHE}" --version
                    OUTPUT_VARIABLE _gamepilot_ccache_version ERROR_QUIET)
    string(REGEX MATCH "version ([0-9]+\\.[0-9]+)" _ "${_gamepilot_ccache_version}")
    set(_gamepilot_launcher "${GAMEPILOT_CCACHE}")
    # ccache 4.8+ takes settings on its command line.
    if(CMAKE_MATCH_1 VERSION_GREATER_EQUAL 4.8)
      list(APPEND _gamepilot_launcher "base_dir=${_gamepilot_root}")
    endif()
    message(STATUS "Using ccache: ${_gamepilot_launcher}")
    set(CMAKE_C_COMPILER_LAUNCHER ${_gamepilot_launcher})
    set(CMAKE_CXX_COMPILER_LAUNCHER ${_gamepilot_launcher})
    set(CMAKE_OBJCXX_COMPILER_LAUNCHER ${_gamepilot_launcher})
  endif()
endif()

set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)
find_package(OpenCV REQUIRED COMPONENTS core imgproc imgcodecs videoio)

# CoreLib, through Arduino-Source's own cmake files. SourceFiles.cmake globs paths
# relative to SerialPrograms/, so the folder is added as a subdirectory with
# PA_CORE_ONLY on (it then includes only SourceFiles.cmake and CoreLib.cmake).
set(PA_SERIAL_PROGRAMS_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/Arduino-Source/SerialPrograms")
cmake_path(NORMAL_PATH PA_SERIAL_PROGRAMS_DIR)
set(PA_CORE_ONLY ON CACHE BOOL "" FORCE)
set(COMMAND_LINE_EXE OFF CACHE BOOL "" FORCE)
set(PA_PYTHON_BINDINGS OFF CACHE BOOL "" FORCE)
set(PA_ASSEMBLY_LISTINGS OFF CACHE BOOL "" FORCE)
set(PA_USE_CCACHE OFF CACHE BOOL "" FORCE)
add_subdirectory("${PA_SERIAL_PROGRAMS_DIR}" "${CMAKE_BINARY_DIR}/pa_core" EXCLUDE_FROM_ALL)
# CoreLib's headers are third-party code here: keep our strict warnings off them.
set_target_properties(CoreLib PROPERTIES SYSTEM TRUE)

function(gamepilot_warnings target)
  if(MSVC)
    target_compile_options(${target} PRIVATE /W4 /WX /utf-8 /external:W0
                                             /external:anglebrackets)
  else()
    target_compile_options(${target} PRIVATE -Wall -Wextra -Wpedantic -Wshadow
                                             -Wconversion -Werror)
  endif()
endfunction()

# The watch page and the hub's, compiled in as bytes: the daemon serves them
# as they are.
function(embed_page page function header)
  add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${function}.cpp"
    COMMAND ${CMAKE_COMMAND} -DINPUT=${CMAKE_CURRENT_SOURCE_DIR}/watch/${page}
            -DOUTPUT=${CMAKE_CURRENT_BINARY_DIR}/${function}.cpp
            -DFUNCTION=${function} -DHEADER=${header}
            -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/embed_watch_page.cmake"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/watch/${page}"
            "${CMAKE_CURRENT_SOURCE_DIR}/cmake/embed_watch_page.cmake"
    VERBATIM)
endfunction()
embed_page(watch.html watch_page watch_server.h)
embed_page(hub.html hub_page watch_hub.h)
embed_page(run.html run_page watch_hub.h)

add_library(gamepilot_core STATIC
  "${CMAKE_CURRENT_BINARY_DIR}/watch_page.cpp"
  "${CMAKE_CURRENT_BINARY_DIR}/hub_page.cpp"
  "${CMAKE_CURRENT_BINARY_DIR}/run_page.cpp"
  src/base64.cpp
  src/blob_find.cpp
  src/board_session.cpp
  src/fake_switch.cpp
  src/frame_stream.cpp
  src/frame_ring.cpp
  src/gzip_reader.cpp
  src/http.cpp
  src/input_lease.cpp
  src/keep_awake.cpp
  src/live_schedule.cpp
  src/log_tail.cpp
  src/mgba_backend.cpp
  src/net.cpp
  src/press_latency.cpp
  src/probe_evaluation.cpp
  src/probes.cpp
  src/rpc.cpp
  src/run_history.cpp
  src/run_journal.cpp
  src/schedule.cpp
  src/sent_results.cpp
  src/server.cpp
  src/server_watch.cpp
  src/switch_backend.cpp
  src/switch_controller.cpp
  src/switch_geometry.cpp
  src/template_store.cpp
  src/video_capture.cpp
  src/view_backend.cpp
  src/view_source.cpp
  src/viewport.cpp
  src/watch_hub.cpp
  src/watch_registry.cpp
  src/watch_server.cpp
)
# The window frame source: ScreenCaptureKit on macOS (Objective-C++), none
# elsewhere (window_capture.h).
if(APPLE)
  enable_language(OBJCXX)
  target_sources(gamepilot_core PRIVATE src/window_capture_mac.mm)
  set_source_files_properties(src/window_capture_mac.mm PROPERTIES
    COMPILE_OPTIONS "-fobjc-arc")
  target_link_libraries(gamepilot_core PUBLIC
    "-framework ScreenCaptureKit" "-framework CoreMedia"
    "-framework CoreVideo" "-framework CoreGraphics" "-framework AppKit"
    "-framework Foundation")
else()
  target_sources(gamepilot_core PRIVATE src/window_capture_none.cpp)
endif()
target_include_directories(gamepilot_core PUBLIC src)
target_include_directories(gamepilot_core SYSTEM PUBLIC ${OpenCV_INCLUDE_DIRS})
target_link_libraries(gamepilot_core PUBLIC CoreLib ${OpenCV_LIBS})
if(WIN32)
  target_link_libraries(gamepilot_core PUBLIC ws2_32)
endif()
gamepilot_warnings(gamepilot_core)

add_executable(gamepilot_daemon src/main.cpp)
target_link_libraries(gamepilot_daemon PRIVATE gamepilot_core)
gamepilot_warnings(gamepilot_daemon)

add_executable(probe_images src/probe_images.cpp)
target_link_libraries(probe_images PRIVATE gamepilot_core)
gamepilot_warnings(probe_images)

add_executable(press_latency src/press_latency_tool.cpp)
target_link_libraries(press_latency PRIVATE gamepilot_core)
gamepilot_warnings(press_latency)

enable_testing()
foreach(test blob_find_test board_session_test contracts_test input_lease_test keep_awake_test
             lockstep_speed_test probes_test
             run_history_test
             switch_backend_test
             switch_geometry_test view_source_test watch_test
             watch_registry_test)
  add_executable(${test} tests/${test}.cpp)
  target_link_libraries(${test} PRIVATE gamepilot_core)
  target_compile_definitions(${test} PRIVATE
    GAMEPILOT_CONTRACTS_DIR="${CMAKE_CURRENT_SOURCE_DIR}/../protocol/v1"
    GAMEPILOT_SWITCH_IMAGES_DIR="${CMAKE_CURRENT_SOURCE_DIR}/../src/games/frlg/readers/test/images/switch/tmcase"
    GAMEPILOT_PLZA_IMAGES_DIR="${CMAKE_CURRENT_SOURCE_DIR}/../src/games/pokemon/plza/readers/test/images/switch"
    GAMEPILOT_SWITCH_CAPTURES_DIR="${CMAKE_CURRENT_SOURCE_DIR}/../src/games/frlg/readers/test/images/switch"
    GAMEPILOT_TEST_OUTPUT_DIR="${CMAKE_CURRENT_BINARY_DIR}")
  gamepilot_warnings(${test})
  add_test(NAME ${test} COMMAND ${test})
endforeach()

add_test(NAME probe_images_test
  COMMAND ${CMAKE_COMMAND} -DTOOL=$<TARGET_FILE:probe_images>
          -P ${CMAKE_CURRENT_SOURCE_DIR}/tests/probe_images_test.cmake
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests/probe_images)
