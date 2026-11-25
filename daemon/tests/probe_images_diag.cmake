# TEMPORARY diagnostic: runs probe_images N times through execute_process and
# counts runs whose stdout came back empty or short.
set(bad 0)
foreach(i RANGE 1 300)
  execute_process(
    COMMAND "${TOOL}" --spec probes.json --game-size 24x16 frame.png
    RESULT_VARIABLE status
    OUTPUT_VARIABLE output
    ERROR_VARIABLE errors)
  string(LENGTH "${output}" n)
  if(NOT status EQUAL 0 OR n LESS 100)
    math(EXPR bad "${bad} + 1")
    message(STATUS "run ${i}: status=[${status}] out_len=${n} err=[${errors}]")
  endif()
endforeach()
message(STATUS "execute_process: ${bad}/300 bad")
