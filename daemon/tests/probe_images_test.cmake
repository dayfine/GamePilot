# Runs probe_images on tests/probe_images and compares its output to
# expected.jsonl there. Run from that folder so image paths print as given.
#
#   cmake -DTOOL=<probe_images> -P probe_images_test.cmake

execute_process(
  COMMAND "${TOOL}" --spec probes.json frame.png
  RESULT_VARIABLE status
  OUTPUT_VARIABLE actual
  ERROR_VARIABLE errors)
if(NOT status EQUAL 0)
  message(FATAL_ERROR "probe_images exited ${status}: ${errors}")
endif()
file(READ expected.jsonl expected)
string(REPLACE "\r" "" actual "${actual}")
if(NOT actual STREQUAL expected)
  message(FATAL_ERROR "probe_images output differs\nexpected: ${expected}\nactual:   ${actual}")
endif()
