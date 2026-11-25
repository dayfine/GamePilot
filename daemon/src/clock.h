// The daemon's one clock: monotonic milliseconds since the daemon started.
// now_ms() is virtual so a test can drive code that reads the clock (the
// latency harness) on time it sets itself (switch_backend_test's ManualClock).

#pragma once

#include <chrono>

namespace gamepilot {

class Clock {
 public:
  Clock() : start_(std::chrono::steady_clock::now()) {}
  virtual ~Clock() = default;
  Clock(const Clock&) = default;
  Clock& operator=(const Clock&) = default;

  virtual double now_ms() const {
    const auto elapsed = std::chrono::steady_clock::now() - start_;
    return std::chrono::duration<double, std::milli>(elapsed).count();
  }

 private:
  std::chrono::steady_clock::time_point start_;
};

}  // namespace gamepilot
