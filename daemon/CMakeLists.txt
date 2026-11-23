cmake_minimum_required(VERSION 3.25)
project(GamePilotDaemon LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)
find_package(OpenCV REQUIRED COMPONENTS core imgproc imgcodecs)

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

add_library(gamepilot_core STATIC
  src/mgba_backend.cpp
  src/net.cpp
  src/probes.cpp
  src/rpc.cpp
  src/schedule.cpp
  src/server.cpp
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

enable_testing()
foreach(test contracts_test probes_test)
  add_executable(${test} tests/${test}.cpp)
  target_link_libraries(${test} PRIVATE gamepilot_core)
  target_compile_definitions(${test} PRIVATE
    GAMEPILOT_CONTRACTS_DIR="${CMAKE_CURRENT_SOURCE_DIR}/../contracts/v1")
  gamepilot_warnings(${test})
  add_test(NAME ${test} COMMAND ${test})
endforeach()
