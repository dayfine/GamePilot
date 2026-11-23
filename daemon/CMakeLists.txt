cmake_minimum_required(VERSION 3.24)
project(GamePilotDaemon LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)
find_package(OpenCV REQUIRED COMPONENTS core)

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

add_executable(gamepilot_daemon src/main.cpp)
target_link_libraries(gamepilot_daemon PRIVATE CoreLib ${OpenCV_LIBS})
target_include_directories(gamepilot_daemon SYSTEM PRIVATE ${OpenCV_INCLUDE_DIRS})

if(MSVC)
  target_compile_options(gamepilot_daemon PRIVATE /W4 /WX /utf-8 /external:W0
                                                  /external:anglebrackets)
else()
  target_compile_options(gamepilot_daemon PRIVATE -Wall -Wextra -Werror)
endif()
