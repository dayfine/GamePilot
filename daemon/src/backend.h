// The I/O boundary: one emulator or console as frame source, input sink and
// frame clock. The daemon steps a backend in lockstep: the backend never runs
// past the frame the daemon asked for.

#pragma once

#include <cstdint>
#include <opencv2/core.hpp>
#include <stdexcept>
#include <string>

#include "viewport.h"

namespace gamepilot {

struct BackendInfo {
  std::string kind;       // "mgba"
  std::string game_code;  // cartridge code as the backend reports it
  double frame_rate = 0;  // frames per second of the emulated machine
  int width = 0;          // frame size in pixels
  int height = 0;
  Viewport viewport;  // the game picture in the frame, and its native size
};

// GBA KEYINPUT bit order.
using KeyMask = std::uint16_t;

class Backend {
 public:
  virtual ~Backend() = default;

  virtual const BackendInfo& info() const = 0;

  // Frames finished so far; the backend is held before the next one.
  virtual std::int64_t seq() const = 0;

  // Holds `mask` from frame `seq()` on (the frame the next step() runs).
  virtual void set_keys(KeyMask mask) = 0;

  // Runs exactly one frame and holds again; returns the new seq().
  virtual std::int64_t step() = 0;

  // The last finished frame (frame `seq()`), BGR, info().width x info().height.
  virtual cv::Mat frame() = 0;

  // Loads a save state file, holds at the loaded frame and returns the new
  // seq(). Throws BackendError on failure.
  virtual std::int64_t load_state(const std::string& path) = 0;

  // Releases keys and lets the backend run on its own.
  virtual void release() = 0;
};

class BackendError : public std::runtime_error {
 public:
  using std::runtime_error::runtime_error;
};

}  // namespace gamepilot
