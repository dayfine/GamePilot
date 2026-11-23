// The daemon's one clock: monotonic milliseconds since the daemon started.

#pragma once

#include <chrono>

namespace gamepilot {

class Clock {
 public:
  Clock() : start_(std::chrono::steady_clock::now()) {}

  double now_ms() const {
    const auto elapsed = std::chrono::steady_clock::now() - start_;
    return std::chrono::duration<double, std::milli>(elapsed).count();
  }

 private:
  std::chrono::steady_clock::time_point start_;
};

}  // namespace gamepilot
