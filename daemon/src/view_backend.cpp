#include "view_backend.h"

#include <cstdio>

namespace gamepilot {

namespace {

// While the video area is not found, look again at most this often (each look
// runs edge detection on a whole frame).
constexpr double kFindCropEveryMs = 1000;
// Frames compared for what moves (ChangeArea), at most this often.
constexpr double kSampleChangeEveryMs = 250;

[[noreturn]] void refuse(const char* what) {
  throw BackendError(std::string("the view backend takes no input: ") + what);
}

}  // namespace

ViewBackend::ViewBackend(std::unique_ptr<FrameSource> source,
                         const Clock& clock, ViewOptions options)
    : source_(std::move(source)),
      clock_(clock),
      options_(options),
      ring_(options.ring_capacity),
      stale_(options.stale_after_ms) {
  cv::Mat first;
  if (!source_->read(first) || first.empty()) {
    throw BackendError("the frame source gave no frame");
  }
  first = cropped(first);
  info_ = BackendInfo{.kind = "view",
                      .game_code = "",
                      .frame_rate = source_->frame_rate(),
                      .width = first.cols,
                      .height = first.rows,
                      .viewport = Viewport{{0, 0, 1, 1}, first.cols, first.rows},
                      .timing = Timing::kLive,
                      .takes_input = false};
  const double t_ms = clock_.now_ms();
  stale_.frame(frame_fingerprint(first), t_ms);
  captured_seq_.store(1);
  captured_t_ms_.store(t_ms);
  ring_.push(CapturedFrame{1, t_ms, std::move(first)});
  capture_thread_ = std::thread([this] { capture_loop(); });
}

ViewBackend::~ViewBackend() {
  stop_.store(true);
  capture_thread_.join();
}

// The source's frame cut to the video: the --crop box, else the area found
// (looked for again when the frame size changes), else the whole frame. The
// finding: the frame's edges once a second (find_video_area), and what moved
// in frames sampled a few times a second (ChangeArea), until one finds it.
cv::Mat ViewBackend::cropped(const cv::Mat& frame) {
  if (options_.crop) {
    return frame(box_to_pixels(*options_.crop, frame.cols, frame.rows));
  }
  if (!options_.find_crop) {
    return frame;
  }
  if (frame.size() != crop_for_) {
    crop_for_ = frame.size();
    crop_.reset();
    change_area_ = ChangeArea();
    find_crop_ms_ = -1e9;
  }
  const double now = clock_.now_ms();
  if (!crop_ && now - sampled_ms_ >= kSampleChangeEveryMs) {
    sampled_ms_ = now;
    change_area_.add(frame);
  }
  if (!crop_ && now - find_crop_ms_ >= kFindCropEveryMs) {
    find_crop_ms_ = now;
    crop_ = find_video_area(frame);
    if (!crop_) {
      crop_ = change_area_.video_area();
    }
    if (crop_) {
      std::fprintf(stderr,
                   "daemon: view: video area %dx%d at %d,%d of %dx%d\n",
                   crop_->width, crop_->height, crop_->x, crop_->y, frame.cols,
                   frame.rows);
    }
  }
  return crop_ ? frame(*crop_) : frame;
}

void ViewBackend::capture_loop() {
  std::int64_t seq = captured_seq_.load();
  cv::Mat image;
  while (!stop_.load() && source_->read(image)) {
    cv::Mat frame = cropped(image).clone();
    const double t_ms = clock_.now_ms();
    {
      const std::lock_guard<std::mutex> hold(stale_lock_);
      stale_.frame(frame_fingerprint(frame), t_ms);
    }
    seq++;
    ring_.push(CapturedFrame{seq, t_ms, std::move(frame)});
    captured_seq_.store(seq);
    captured_t_ms_.store(t_ms);
  }
}

std::optional<FrameStamp> ViewBackend::next_frame(double timeout_ms) {
  std::optional<CapturedFrame> frame = ring_.pop(timeout_ms);
  if (!frame) {
    return std::nullopt;
  }
  current_ = std::move(*frame);
  // The crop was found, or the window resized: the frames' size from now on.
  if (current_.image.cols != info_.width || current_.image.rows != info_.height) {
    info_.width = current_.image.cols;
    info_.height = current_.image.rows;
    info_.viewport.game_width = info_.width;
    info_.viewport.game_height = info_.height;
  }
  return FrameStamp{current_.seq, current_.t_ms};
}

// Covered or hidden (the source's word) before stale: they say why.
std::optional<SourceStatus> ViewBackend::source_status() {
  std::optional<SourceStatus> visible = source_->visibility();
  if (visible && visible->state != SourceState::kLive) {
    return visible;
  }
  const double now = clock_.now_ms();
  double unchanged = 0;
  bool stale = false;
  {
    const std::lock_guard<std::mutex> hold(stale_lock_);
    unchanged = stale_.unchanged_ms(now);
    stale = stale_.stale(now);
  }
  std::string detail = visible ? visible->detail : std::string();
  if (stale) {
    char text[48];
    std::snprintf(text, sizeof text, "unchanged for %.0f s", unchanged / 1000);
    detail = detail.empty() ? text : std::string(text) + "; " + detail;
    return SourceStatus{SourceState::kStale, detail};
  }
  return SourceStatus{SourceState::kLive, detail};
}

BackendHealth ViewBackend::health() const {
  BackendHealth health;
  health.threads.push_back(
      ThreadBeat{"capture", captured_seq_.load(), captured_t_ms_.load()});
  health.ring_depth = ring_.depth();
  health.ring_capacity = ring_.capacity();
  return health;
}

void ViewBackend::set_keys(KeyMask) { refuse("keys"); }
void ViewBackend::queue_keys(KeyMask, double) { refuse("keys"); }
void ViewBackend::drop_queued_keys() {}
std::int64_t ViewBackend::step() { refuse("frames are not stepped"); }
std::int64_t ViewBackend::load_state(const std::string&) {
  refuse("no save states");
}
std::int64_t ViewBackend::save_state(const std::string&) {
  refuse("no save states");
}

}  // namespace gamepilot
