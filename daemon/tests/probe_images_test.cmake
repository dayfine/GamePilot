# Runs probe_images on tests/probe_images and compares its output to
# expected.jsonl there. Run from that folder so image paths print as given.
# frame.png is a whole 24x16 game picture; capture.png is the same picture at
# twice the size inside black side bars, so with --viewport its results must be
# frame.png's. --viewport native names the whole image; it sets the game size
# too (1920x1080), so the --game-size after it puts 24x16 back and frame.png's
# results come out again.
#
#   cmake -DTOOL=<probe_images> -P probe_images_test.cmake

set(actual "")
foreach(run "frame.png" "--viewport;0.125,0,0.75,1;capture.png"
            "--viewport;native;--game-size;24x16;frame.png")
  execute_process(
    COMMAND "${TOOL}" --spec probes.json --game-size 24x16 ${run}
    RESULT_VARIABLE status
    OUTPUT_VARIABLE output
    ERROR_VARIABLE errors)
  if(NOT status EQUAL 0)
    message(FATAL_ERROR "probe_images ${run} exited ${status}: ${errors}")
  endif()
  string(APPEND actual "${output}")
endforeach()
file(READ expected.jsonl expected)
string(REPLACE "\r" "" actual "${actual}")
if(NOT actual STREQUAL expected)
  message(FATAL_ERROR "probe_images output differs\nexpected: ${expected}\nactual:   ${actual}")
endif()
