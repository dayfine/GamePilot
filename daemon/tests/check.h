// A minimal check macro for the daemon's ctest executables: each failure prints
// and the test returns nonzero.

#pragma once

#include <cstdio>

namespace gamepilot::test {

inline int& failures() {
  static int count = 0;
  return count;
}

}  // namespace gamepilot::test

#define CHECK(condition)                                                    \
  do {                                                                      \
    if (!(condition)) {                                                     \
      std::fprintf(stderr, "%s:%d: CHECK failed: %s\n", __FILE__, __LINE__, \
                   #condition);                                             \
      ::gamepilot::test::failures()++;                                      \
    }                                                                       \
  } while (false)

#define TEST_RESULT()                                  \
  (::gamepilot::test::failures() == 0                  \
       ? (std::fputs("ok\n", stderr), 0)               \
       : (std::fprintf(stderr, "%d failures\n",        \
                       ::gamepilot::test::failures()), \
          1))
