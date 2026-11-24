#include "frame_stream.h"

#include <algorithm>
#include <charconv>
#include <chrono>
#include <cstdio>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>
#include <utility>

#include "http.h"

namespace gamepilot {

namespace {

// Frames this wide or less (the GBA's 240x160) are doubled, not scaled down.
// Doubling puts each game pixel on 2x2 pixels, so JPEG's 8x8 blocks hold whole
// game pixels; 4:4:4 at quality 90 keeps text edges and colours clean
// (measured on FRLG menus: about 55 KB and 0.4 ms a frame).
constexpr int kSmallFrameWidth = 320;
constexpr int kSmallFrameQuality = 90;
// A capture card's frame: 1280x720 at quality 80 is about 110 KB.
constexpr int kLargeFrameQuality = 80;
constexpr int kWidthStep = 32;
// An offer this much early still counts as due, so a 60 Hz source gives
// every second frame at 30 fps rather than every third.
constexpr double kOfferSlackMs = 4;
// The worker's wait: while a viewer is mid-frame it retries this often,
// otherwise it sleeps until a frame or a viewer comes.
constexpr auto kRetryWait = std::chrono::milliseconds(4);
constexpr auto kIdleWait = std::chrono::milliseconds(500);
// A viewer that takes no byte for this long is dropped.
constexpr double kStalledMs = 10000;
constexpr double kReportMs = 10000;

}  // namespace

std::string encode_stream_frame(const cv::Mat& frame, int width) {
  std::vector<unsigned char> bytes;
  if (frame.cols <= kSmallFrameWidth) {
    cv::Mat doubled;
    cv::resize(frame, doubled, cv::Size(), 2, 2, cv::INTER_NEAREST);
    cv::imencode(".jpg", doubled, bytes,
                 {cv::IMWRITE_JPEG_QUALITY, kSmallFrameQuality,
                  cv::IMWRITE_JPEG_SAMPLING_FACTOR,
                  cv::IMWRITE_JPEG_SAMPLING_FACTOR_444});
  } else {
    cv::Mat scaled = frame;
    if (frame.cols > width) {
      const int height = static_cast<int>(
          static_cast<double>(frame.rows) * width / frame.cols + 0.5);
      // Area averaging is cheap at a whole factor (1080p to 960 wide) but
      // costs 6 ms of CPU at 1080p to 720p (measured), where bilinear is
      // 0.3 ms and looks the same on game screens.
      const int interpolation =
          frame.cols % width == 0 ? cv::INTER_AREA : cv::INTER_LINEAR;
      cv::resize(frame, scaled, cv::Size(width, height), 0, 0, interpolation);
    }
    cv::imencode(".jpg", scaled, bytes,
                 {cv::IMWRITE_JPEG_QUALITY, kLargeFrameQuality});
  }
  return std::string(bytes.begin(), bytes.end());
}

int stream_width(std::string_view asked, int fallback) {
  int width = 0;
  const auto [end, error] =
      std::from_chars(asked.data(), asked.data() + asked.size(), width);
  if (asked.empty() || error != std::errc() ||
      end != asked.data() + asked.size()) {
    return fallback;
  }
  width = std::clamp(width, kStreamMinWidth, kStreamMaxWidth);
  return width / kWidthStep * kWidthStep;
}

FrameStream::FrameStream(StreamOptions options)
    : options_(options), worker_([this] { work(); }) {}

FrameStream::~FrameStream() {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    quit_ = true;
  }
  wake_.notify_one();
  worker_.join();
}

bool FrameStream::add_viewer(Socket socket, int width) {
  if (viewer_count_.load() >= kStreamMaxViewers) {
    return false;
  }
  viewer_count_++;
  offered_seq_ = -1;  // a new viewer gets the current frame even if it is old
  {
    std::lock_guard<std::mutex> lock(mutex_);
    Viewer viewer;
    viewer.socket = std::move(socket);
    viewer.width = width;
    joining_.push_back(std::move(viewer));
  }
  wake_.notify_one();
  return true;
}

bool FrameStream::wants_frame(std::int64_t seq, double now_ms) const {
  return viewer_count_.load() > 0 && seq != offered_seq_ &&
         now_ms - offered_ms_ >= 1000.0 / options_.fps - kOfferSlackMs;
}

void FrameStream::offer(const cv::Mat& frame, std::int64_t seq,
                        double now_ms) {
  offered_ms_ = now_ms;
  offered_seq_ = seq;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    latest_ = frame;
    latest_seq_ = seq;
    fresh_ = true;
  }
  wake_.notify_one();
}

void FrameStream::work() {
  bool busy = false;
  std::unique_lock<std::mutex> lock(mutex_);
  while (true) {
    wake_.wait_for(lock, busy ? kRetryWait : kIdleWait, [this] {
      return quit_ || fresh_ || !joining_.empty();
    });
    if (quit_) {
      break;
    }
    for (Viewer& viewer : joining_) {
      set_nonblocking(viewer.socket);
      viewer.progress_ms = clock_.now_ms();
      viewer.since_ms = viewer.progress_ms;
      std::fprintf(stderr, "daemon: stream viewer joined (%d px wide), %d now\n",
                   viewer.width, viewer_count_.load());
      viewers_.push_back(std::move(viewer));
    }
    joining_.clear();
    cv::Mat frame;
    std::int64_t seq = -1;
    if (fresh_) {
      frame = latest_;
      latest_ = cv::Mat();
      seq = latest_seq_;
      fresh_ = false;
    }
    lock.unlock();
    if (!frame.empty()) {
      encode(frame, seq);
    }
    busy = send_to_viewers();
    report(clock_.now_ms());
    lock.lock();
  }
}

// One encoding per width the viewers asked for; a small frame is the same at
// every width, so it is encoded once.
int FrameStream::part_key(int width) const {
  return frame_cols_ <= kSmallFrameWidth ? 0 : std::min(width, frame_cols_);
}

void FrameStream::encode(const cv::Mat& frame, std::int64_t seq) {
  frame_cols_ = frame.cols;
  parts_.clear();
  for (const Viewer& viewer : viewers_) {
    const int key = part_key(viewer.width);
    if (parts_.contains(key)) {
      continue;
    }
    const double start = clock_.now_ms();
    const std::string jpeg = encode_stream_frame(frame, viewer.width);
    encode_ms_ += clock_.now_ms() - start;
    encoded_++;
    encoded_bytes_ += static_cast<std::int64_t>(jpeg.size());
    parts_[key] =
        std::make_shared<const std::string>(multipart_part("image/jpeg", jpeg));
  }
  parts_seq_ = seq;
}

bool FrameStream::send_to_viewers() {
  const double now = clock_.now_ms();
  bool busy = false;
  for (Viewer& viewer : viewers_) {
    if (!viewer.sending && viewer.seq < parts_seq_) {
      const auto part = parts_.find(part_key(viewer.width));
      if (part != parts_.end()) {
        viewer.sending = part->second;
        viewer.sent = 0;
        viewer.seq = parts_seq_;
      }
    }
    if (!viewer.sending) {
      continue;
    }
    const std::string& part = *viewer.sending;
    const auto sent = viewer.socket.send_some(part.data() + viewer.sent,
                                              part.size() - viewer.sent);
    if (!sent || now - viewer.progress_ms > kStalledMs) {
      viewer.socket.close();
      continue;
    }
    if (*sent > 0) {
      viewer.sent += *sent;
      viewer.progress_ms = now;
    }
    if (viewer.sent == part.size()) {
      viewer.sending.reset();
      viewer.frames++;
    } else {
      busy = true;
    }
  }
  const auto gone = std::erase_if(
      viewers_, [](const Viewer& viewer) { return !viewer.socket.valid(); });
  if (gone > 0) {
    viewer_count_ -= static_cast<int>(gone);
    std::fprintf(stderr, "daemon: stream viewer left, %d now\n",
                 viewer_count_.load());
  }
  return busy;
}

// Every 10 s while a viewer is connected: what the stream costs and what the
// slowest viewer got.
void FrameStream::report(double now_ms) {
  if (viewers_.empty()) {
    report_ms_ = now_ms;
    encoded_ = 0;
    encode_ms_ = 0;
    encoded_bytes_ = 0;
    return;
  }
  if (now_ms - report_ms_ < kReportMs) {
    return;
  }
  const double seconds = (now_ms - report_ms_) / 1000.0;
  report_ms_ = now_ms;
  if (encoded_ > 0) {
    double slowest = 1e9;
    for (const Viewer& viewer : viewers_) {
      slowest = std::min(slowest, static_cast<double>(viewer.frames) * 1000.0 /
                                      (now_ms - viewer.since_ms));
    }
    std::fprintf(stderr,
                 "daemon: stream: %zu viewer%s, %.1f encodes/s, %.2f ms and "
                 "%lld bytes each; slowest viewer %.1f frames/s\n",
                 viewers_.size(), viewers_.size() == 1 ? "" : "s",
                 static_cast<double>(encoded_) / seconds,
                 encode_ms_ / static_cast<double>(encoded_),
                 static_cast<long long>(encoded_bytes_ / encoded_),
                 slowest);
  }
  for (Viewer& viewer : viewers_) {
    viewer.frames = 0;
    viewer.since_ms = now_ms;
  }
  encoded_ = 0;
  encode_ms_ = 0;
  encoded_bytes_ = 0;
}

}  // namespace gamepilot
