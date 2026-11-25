#include "switch_backend.h"

#include <chrono>
#include <cmath>

namespace gamepilot {

SwitchBackend::SwitchBackend(std::unique_ptr<FrameSource> source,
                             BoardSession& controller, const Clock& clock,
                             SwitchOptions options)
    : source_(std::move(source)),
      controller_(controller),
      clock_(clock),
      ring_(options.ring_capacity) {
  cv::Mat first;
  if (!source_->read(first) || first.empty()) {
    throw BackendError("the frame source gave no frame");
  }
  info_ = BackendInfo{.kind = "switch",
                      .game_code = "",
                      .frame_rate = source_->frame_rate(),
                      .width = first.cols,
                      .height = first.rows,
                      .viewport = options.viewport,
                      .timing = Timing::kLive,
                      .takes_input = true};
  const double t_ms = clock_.now_ms();
  captured_seq_.store(1);
  captured_t_ms_.store(t_ms);
  ring_.push(CapturedFrame{1, t_ms, std::move(first)});
  capture_thread_ = std::thread([this] { capture_loop(); });
}

SwitchBackend::~SwitchBackend() {
  stop_.store(true);
  capture_thread_.join();
}

void SwitchBackend::capture_loop() {
  std::int64_t seq = captured_seq_.load();
  cv::Mat image;
  while (!stop_.load() && source_->read(image)) {
    const double t_ms = clock_.now_ms();
    seq++;
    ring_.push(CapturedFrame{seq, t_ms, image.clone()});
    captured_seq_.store(seq);
    captured_t_ms_.store(t_ms);
  }
}

std::optional<FrameStamp> SwitchBackend::next_frame(double timeout_ms) {
  std::optional<CapturedFrame> frame = ring_.pop(timeout_ms);
  if (!frame) {
    return std::nullopt;
  }
  if (current_.seq > 0 && frame->seq > current_.seq + 1) {
    gaps_++;
    gap_frames_ += frame->seq - current_.seq - 1;
  }
  current_ = std::move(*frame);
  return FrameStamp{current_.seq, current_.t_ms};
}

void SwitchBackend::queue_keys(KeyMask mask, const Sticks& sticks, double ms) {
  const auto rounded = static_cast<std::uint32_t>(std::llround(ms));
  // Blocks while the board's command queue is full, as the C++ does.
  controller_.send_state(pro_buttons_for_state(mask, sticks), rounded);
}

void SwitchBackend::drop_queued_keys() { controller_.cancel_queued(); }

void SwitchBackend::replace_queued_keys() { controller_.replace_on_next(); }

void SwitchBackend::set_keys(KeyMask mask) {
  queue_keys(mask, Sticks{}, 1000.0 / info_.frame_rate);
}

std::int64_t SwitchBackend::step() {
  throw BackendError("the switch backend is live: frames are not stepped");
}

std::int64_t SwitchBackend::load_state(const std::string&) {
  throw BackendError("the switch has no save states");
}

std::int64_t SwitchBackend::save_state(const std::string&) {
  throw BackendError("the switch has no save states");
}

void SwitchBackend::release() { queue_keys(0, Sticks{}, 0); }

BackendHealth SwitchBackend::health() const {
  BackendHealth health;
  health.threads.push_back(
      ThreadBeat{"capture", captured_seq_.load(), captured_t_ms_.load()});
  health.ring_depth = ring_.depth();
  health.ring_capacity = ring_.capacity();
  health.gaps = gaps_;
  health.gap_frames = gap_frames_;
  return health;
}

}  // namespace gamepilot
