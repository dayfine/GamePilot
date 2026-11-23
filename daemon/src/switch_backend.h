// Backend for a Switch: a frame source (capture card or recorded video) and a
// PABotBase2 wired controller. Live, not lockstep: a capture thread reads
// frames at the source's rate, stamps each with a seq and the daemon clock,
// and pushes it into the FrameRing; the server thread takes frames from the
// ring (next_frame) and sends inputs (queue_keys). Design: PR #44, 5.3.
//
// What each thread touches: the capture thread owns the source and its
// heartbeat; the server thread owns the current frame and the controller. The
// ring is all they share.

#pragma once

#include <atomic>
#include <cstdint>
#include <memory>
#include <thread>

#include "backend.h"
#include "clock.h"
#include "frame_ring.h"
#include "switch_controller.h"
#include "video_capture.h"

namespace gamepilot {

struct SwitchOptions {
  // Where the game picture sits in the frame; by default the fork's FRLG
  // GAME_BOX on a 1080p capture, a GBA picture of 240x160.
  Viewport viewport{Box{0.09375, 0.00462963, 0.8125, 0.962963}, 240, 160};
  std::size_t ring_capacity = 8;
};

class SwitchBackend : public Backend {
 public:
  // Reads the first frame (for the frame size) and starts the capture thread.
  // Throws BackendError if the source gives no frame.
  SwitchBackend(std::unique_ptr<FrameSource> source,
                Pabb2Controller& controller, const Clock& clock,
                SwitchOptions options);
  ~SwitchBackend() override;

  const BackendInfo& info() const override { return info_; }
  std::int64_t seq() const override { return current_.seq; }
  cv::Mat frame() override { return current_.image; }

  // Inputs are timed in wall time here: set_keys holds `mask` for one frame.
  void set_keys(KeyMask mask) override;
  std::int64_t step() override;
  std::int64_t load_state(const std::string& path) override;
  std::int64_t save_state(const std::string& path) override;
  void release() override;

  std::optional<FrameStamp> next_frame(double timeout_ms) override;
  void queue_keys(KeyMask mask, double ms) override;
  BackendHealth health() const override;

 private:
  void capture_loop();

  std::unique_ptr<FrameSource> source_;
  Pabb2Controller& controller_;
  const Clock& clock_;
  BackendInfo info_;
  FrameRing ring_;
  CapturedFrame current_;
  std::int64_t gaps_ = 0;
  std::int64_t gap_frames_ = 0;

  // The capture thread's heartbeat: last frame captured and when.
  std::atomic<std::int64_t> captured_seq_{0};
  std::atomic<double> captured_t_ms_{0};
  std::atomic<bool> stop_{false};
  std::thread capture_thread_;
};

}  // namespace gamepilot
