cmake_minimum_required(VERSION 3.25)
project(GamePilotDaemon LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

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

add_library(gamepilot_core STATIC
  "${CMAKE_CURRENT_BINARY_DIR}/watch_page.cpp"
  "${CMAKE_CURRENT_BINARY_DIR}/hub_page.cpp"
  src/base64.cpp
  src/board_session.cpp
  src/fake_switch.cpp
  src/frame_ring.cpp
  src/http.cpp
  src/live_schedule.cpp
  src/mgba_backend.cpp
  src/net.cpp
  src/press_latency.cpp
  src/probe_evaluation.cpp
  src/probes.cpp
  src/rpc.cpp
  src/schedule.cpp
  src/sent_results.cpp
  src/server.cpp
  src/server_watch.cpp
  src/switch_backend.cpp
  src/switch_controller.cpp
  src/switch_geometry.cpp
  src/template_store.cpp
  src/video_capture.cpp
  src/viewport.cpp
  src/watch_hub.cpp
  src/watch_registry.cpp
  src/watch_server.cpp
)
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
foreach(test board_session_test contracts_test probes_test switch_backend_test
             switch_geometry_test watch_test watch_registry_test)
  add_executable(${test} tests/${test}.cpp)
  target_link_libraries(${test} PRIVATE gamepilot_core)
  target_compile_definitions(${test} PRIVATE
    GAMEPILOT_CONTRACTS_DIR="${CMAKE_CURRENT_SOURCE_DIR}/../contracts/v1"
    GAMEPILOT_SWITCH_IMAGES_DIR="${CMAKE_CURRENT_SOURCE_DIR}/../src/games/frlg/readers/test/images/switch/tmcase"
    GAMEPILOT_SWITCH_CAPTURES_DIR="${CMAKE_CURRENT_SOURCE_DIR}/../src/games/frlg/readers/test/images/switch"
    GAMEPILOT_TEST_OUTPUT_DIR="${CMAKE_CURRENT_BINARY_DIR}")
  gamepilot_warnings(${test})
  add_test(NAME ${test} COMMAND ${test})
endforeach()

add_test(NAME probe_images_test
  COMMAND ${CMAKE_COMMAND} -DTOOL=$<TARGET_FILE:probe_images>
          -P ${CMAKE_CURRENT_SOURCE_DIR}/tests/probe_images_test.cmake
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests/probe_images)
