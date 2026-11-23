#include "frame_ring.h"

#include <chrono>

namespace gamepilot {

void FrameRing::push(CapturedFrame frame) {
  {
    std::lock_guard<std::mutex> guard(lock_);
    if (frames_.size() >= capacity_) {
      frames_.pop_front();
    }
    frames_.push_back(std::move(frame));
  }
  ready_.notify_one();
}

std::optional<CapturedFrame> FrameRing::pop(double timeout_ms) {
  std::unique_lock<std::mutex> guard(lock_);
  ready_.wait_for(guard, std::chrono::duration<double, std::milli>(timeout_ms),
                  [&] { return !frames_.empty(); });
  if (frames_.empty()) {
    return std::nullopt;
  }
  CapturedFrame frame = std::move(frames_.front());
  frames_.pop_front();
  return frame;
}

std::size_t FrameRing::depth() const {
  std::lock_guard<std::mutex> guard(lock_);
  return frames_.size();
}

}  // namespace gamepilot
