// The capture ring between the two Switch daemon threads (design: PR #44, 5.3):
// the capture thread pushes stamped frames, the server thread takes them in
// order. Bounded; when full, a push drops the oldest frame, and the reader sees
// the hole as a jump in `seq` (a gap). The ring is the only state the two
// threads share.
//
// It holds whole frames for now (a 1080p frame is 6 MB, so keep it short);
// holding only the subscribed boxes' crops is the design's next step.

#pragma once

#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <mutex>
#include <opencv2/core.hpp>
#include <optional>

namespace gamepilot {

struct CapturedFrame {
  std::int64_t seq = 0;  // 1, 2, ... in capture order
  double t_ms = 0;       // daemon clock when the capture returned it
  cv::Mat image;         // BGR
};

class FrameRing {
 public:
  explicit FrameRing(std::size_t capacity) : capacity_(capacity) {}

  // Adds a frame; drops the oldest when full.
  void push(CapturedFrame frame);

  // Takes the oldest frame, waiting up to `timeout_ms` for one.
  std::optional<CapturedFrame> pop(double timeout_ms);

  std::size_t depth() const;
  std::size_t capacity() const { return capacity_; }

 private:
  const std::size_t capacity_;
  mutable std::mutex lock_;
  std::condition_variable ready_;
  std::deque<CapturedFrame> frames_;
};

}  // namespace gamepilot
