#include "video_capture.h"

#include <charconv>
#include <chrono>
#include <thread>

#include "backend.h"

namespace gamepilot {

namespace {

class CaptureCard : public FrameSource {
 public:
  explicit CaptureCard(const CaptureCardConfig& config) {
    int index = 0;
    const char* end = config.device.data() + config.device.size();
    const auto [ptr, error] = std::from_chars(config.device.data(), end, index);
    const bool is_index = error == std::errc() && ptr == end;
    const bool opened = is_index ? capture_.open(index, cv::CAP_ANY)
                                 : capture_.open(config.device, cv::CAP_ANY);
    if (!opened) {
      throw BackendError("cannot open capture device " + config.device);
    }
    if (config.fourcc.size() == 4) {
      capture_.set(cv::CAP_PROP_FOURCC,
                   cv::VideoWriter::fourcc(config.fourcc[0], config.fourcc[1],
                                           config.fourcc[2], config.fourcc[3]));
    }
    capture_.set(cv::CAP_PROP_FRAME_WIDTH, config.width);
    capture_.set(cv::CAP_PROP_FRAME_HEIGHT, config.height);
    capture_.set(cv::CAP_PROP_FPS, config.frame_rate);
    const double rate = capture_.get(cv::CAP_PROP_FPS);
    frame_rate_ = rate > 0 ? rate : config.frame_rate;
  }

  bool read(cv::Mat& frame) override { return capture_.read(frame); }
  double frame_rate() const override { return frame_rate_; }

 private:
  cv::VideoCapture capture_;
  double frame_rate_ = 0;
};

class VideoReplay : public FrameSource {
 public:
  VideoReplay(const std::string& path, const Clock& clock) : clock_(clock) {
    if (!capture_.open(path, cv::CAP_ANY)) {
      throw BackendError("cannot open video " + path);
    }
    frame_rate_ = capture_.get(cv::CAP_PROP_FPS);
    if (!(frame_rate_ > 0)) {
      throw BackendError("video has no frame rate: " + path);
    }
  }

  bool read(cv::Mat& frame) override {
    if (!capture_.read(frame)) {
      return false;
    }
    const double now = clock_.now_ms();
    if (frames_ == 0) {
      start_ms_ = now;
    }
    const double due =
        start_ms_ + static_cast<double>(frames_) * 1000.0 / frame_rate_;
    frames_++;
    if (due > now) {
      std::this_thread::sleep_for(
          std::chrono::duration<double, std::milli>(due - now));
    }
    return true;
  }

  double frame_rate() const override { return frame_rate_; }

 private:
  const Clock& clock_;
  cv::VideoCapture capture_;
  double frame_rate_ = 0;
  double start_ms_ = 0;
  long long frames_ = 0;
};

}  // namespace

std::unique_ptr<FrameSource> open_capture_card(
    const CaptureCardConfig& config) {
  return std::make_unique<CaptureCard>(config);
}

std::unique_ptr<FrameSource> open_video_replay(const std::string& path,
                                               const Clock& clock) {
  return std::make_unique<VideoReplay>(path, clock);
}

}  // namespace gamepilot
