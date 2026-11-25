// A view-only backend: frames from a source another program owns (an app's
// window, window_capture.h; or a recorded video), shown on the watch page and
// served to probes, with no input at all. It has no controller: the server
// refuses input and the lease for it (info().takes_input), and it never
// presses a keep-awake key. Live, like the Switch backend: a capture thread
// reads the source, crops it to the video, stamps and rings each frame.
//
// The crop is a box of the source's frame (--crop), or found on the frames
// (find_video_area, ChangeArea) until it is, and again when the frame size
// changes (the window was resized); the whole frame is shown until then. Each second the backend says whether the picture is
// live, stale (unchanged for `stale_after_ms`) or covered (the source's own
// visibility: a window behind others), status().

#pragma once

#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>

#include "backend.h"
#include "clock.h"
#include "frame_ring.h"
#include "video_capture.h"
#include "view_source.h"

namespace gamepilot {

struct ViewOptions {
  std::optional<Box> crop;  // none: the whole frame
  bool find_crop = false;   // look for the video area (find_video_area)
  double stale_after_ms = 10000;
  std::size_t ring_capacity = 4;
};

class ViewBackend : public Backend {
 public:
  // Reads the first frame (for the frame size) and starts the capture thread.
  // Throws BackendError if the source gives no frame.
  ViewBackend(std::unique_ptr<FrameSource> source, const Clock& clock,
              ViewOptions options);
  ~ViewBackend() override;

  // Its width and height follow the frames (the crop found, a resize).
  const BackendInfo& info() const override { return info_; }
  std::int64_t seq() const override { return current_.seq; }
  cv::Mat frame() override { return current_.image; }

  // Each throws BackendError: nothing here takes input or has states.
  void set_keys(KeyMask mask) override;
  std::int64_t step() override;
  std::int64_t load_state(const std::string& path) override;
  std::int64_t save_state(const std::string& path) override;
  void queue_keys(KeyMask mask, const Sticks& sticks, double ms) override;
  void drop_queued_keys() override;
  // Nothing to release.
  void release() override {}

  std::optional<FrameStamp> next_frame(double timeout_ms) override;
  BackendHealth health() const override;
  std::optional<SourceStatus> source_status() override;

 private:
  void capture_loop();
  cv::Mat cropped(const cv::Mat& frame);

  std::unique_ptr<FrameSource> source_;
  const Clock& clock_;
  ViewOptions options_;
  BackendInfo info_;
  FrameRing ring_;
  CapturedFrame current_;

  // The capture thread's: the crop in force and the frame size it is for.
  std::optional<cv::Rect> crop_;
  cv::Size crop_for_;
  double find_crop_ms_ = -1e9;
  ChangeArea change_area_;
  double sampled_ms_ = -1e9;

  mutable std::mutex stale_lock_;
  StaleDetector stale_;

  std::atomic<std::int64_t> captured_seq_{0};
  std::atomic<double> captured_t_ms_{0};
  std::atomic<bool> stop_{false};
  std::thread capture_thread_;
};

}  // namespace gamepilot
