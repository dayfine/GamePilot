// The I/O boundary: one emulator or console as frame source, input sink and
// frame clock. A lockstep backend (mGBA) never runs past the frame the daemon
// asked for; a live backend (the Switch) runs on its own: frames come at the
// capture card's rate and inputs are timed in wall time.

#pragma once

#include <cstdint>
#include <opencv2/core.hpp>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

#include "viewport.h"

namespace gamepilot {

enum class Timing { kLockstep, kLive };

struct BackendInfo {
  std::string kind;       // "mgba", "switch"
  std::string game_code;  // cartridge code as the backend reports it
  double frame_rate = 0;  // frames per second of the emulated machine
  int width = 0;          // frame size in pixels
  int height = 0;
  Viewport viewport;  // the game picture in the frame, and its native size
  Timing timing = Timing::kLockstep;
};

// GBA KEYINPUT bit order.
using KeyMask = std::uint16_t;

// A thread's last sign of life: the last frame it handled and when.
struct ThreadBeat {
  std::string name;
  std::int64_t seq = 0;
  double t_ms = 0;
};

// What a live backend reports for the daemon's `status`.
struct BackendHealth {
  std::vector<ThreadBeat> threads;
  std::size_t ring_depth = 0;
  std::size_t ring_capacity = 0;
  std::int64_t gaps = 0;        // jumps in seq seen by the reader
  std::int64_t gap_frames = 0;  // frames lost in them
};

// A frame a live backend made current.
struct FrameStamp {
  std::int64_t seq = 0;
  double t_ms = 0;  // capture time on the daemon clock
};

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

  // Saves the emulator's state to a file and returns seq(). Throws
  // BackendError on failure.
  virtual std::int64_t save_state(const std::string& path) = 0;

  // Releases keys and lets the backend run on its own.
  virtual void release() = 0;

  // Live backends only. Makes the next captured frame current (frame(),
  // seq()), waiting up to `timeout_ms` for one; nullopt if none came.
  virtual std::optional<FrameStamp> next_frame(double timeout_ms);

  // Live backends only. Holds `mask` for `ms` from now, after inputs already
  // queued.
  virtual void queue_keys(KeyMask mask, double ms);

  // Live backends only. Drops the inputs queued with queue_keys() that have
  // not run yet and cuts short the one running, so a cancel takes effect now
  // rather than after the device has played out the queue.
  virtual void drop_queued_keys();

  virtual BackendHealth health() const { return {}; }
};

class BackendError : public std::runtime_error {
 public:
  using std::runtime_error::runtime_error;
};

inline std::optional<FrameStamp> Backend::next_frame(double) {
  throw BackendError(info().kind + " is not a live backend");
}

inline void Backend::queue_keys(KeyMask, double) {
  throw BackendError(info().kind + " is not a live backend");
}

inline void Backend::drop_queued_keys() {
  throw BackendError(info().kind + " is not a live backend");
}

}  // namespace gamepilot
