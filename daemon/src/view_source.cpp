#include "view_source.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <opencv2/imgproc.hpp>

#include "rpc.h"

namespace gamepilot {

namespace {

// frame_fingerprint's sampling steps, in pixels.
constexpr int kFingerprintStepX = 7;
constexpr int kFingerprintStepY = 5;
constexpr std::uint64_t kFnvOffset = 1469598103934665603ULL;
constexpr std::uint64_t kFnvPrime = 1099511628211ULL;

// find_video_area's limits.
constexpr double kVideoAspect = 16.0 / 9.0;
constexpr double kAspectTolerance = 0.03;
constexpr double kMinAreaShare = 0.1;
// A contour fills at least this much of its bounding box to count as a
// rectangle.
constexpr double kMinFill = 0.85;
constexpr double kCannyLow = 50;
constexpr double kCannyHigh = 150;

constexpr int kGrid = 32;

// ChangeArea: a pixel changed when a channel moved by more than this; changed
// pixels this close together are one area (the dilation is undone after).
constexpr int kChangeThreshold = 8;
constexpr int kChangeJoin = 4;

// Big enough and 16:9 enough to be the video.
bool video_shaped(const cv::Rect& box, cv::Size frame) {
  const double aspect = static_cast<double>(box.width) / box.height;
  return box.area() >= kMinAreaShare * frame.area() &&
         std::abs(aspect / kVideoAspect - 1) <= kAspectTolerance;
}

// cv::boundingRect and cv::contourArea moved out of imgproc in OpenCV 5
// (geometry), so both are here for either version.
cv::Rect bounding_rect(const std::vector<cv::Point>& contour) {
  cv::Point low = contour.front();
  cv::Point high = contour.front();
  for (const cv::Point& point : contour) {
    low = {std::min(low.x, point.x), std::min(low.y, point.y)};
    high = {std::max(high.x, point.x), std::max(high.y, point.y)};
  }
  return {low, high + cv::Point(1, 1)};
}

// The shoelace formula.
double contour_area(const std::vector<cv::Point>& contour) {
  double twice = 0;
  for (std::size_t i = 0; i < contour.size(); i++) {
    const cv::Point& a = contour[i];
    const cv::Point& b = contour[(i + 1) % contour.size()];
    twice += static_cast<double>(a.x) * b.y - static_cast<double>(b.x) * a.y;
  }
  return std::abs(twice) / 2;
}

}  // namespace

const char* source_state_name(SourceState state) {
  switch (state) {
    case SourceState::kLive:
      return "live";
    case SourceState::kStale:
      return "stale";
    case SourceState::kCovered:
      return "covered";
    case SourceState::kHidden:
      return "hidden";
  }
  return "live";
}

std::string source_status_json(const SourceStatus& status) {
  pa::JsonObject json;
  json["state"] = std::string(source_state_name(status.state));
  json["detail"] = status.detail;
  return to_line(pa::JsonValue(std::move(json)));
}

std::uint64_t frame_fingerprint(const cv::Mat& frame) {
  std::uint64_t hash = kFnvOffset;
  if (frame.empty() || frame.type() != CV_8UC3) {
    return hash;
  }
  for (int y = 0; y < frame.rows; y += kFingerprintStepY) {
    const cv::Vec3b* row = frame.ptr<cv::Vec3b>(y);
    for (int x = 0; x < frame.cols; x += kFingerprintStepX) {
      hash = (hash ^ row[x][1]) * kFnvPrime;
    }
  }
  return (hash ^ static_cast<std::uint64_t>(frame.cols)) * kFnvPrime;
}

void StaleDetector::frame(std::uint64_t fingerprint, double now_ms) {
  if (last_ != fingerprint) {
    last_ = fingerprint;
    changed_ms_ = now_ms;
  }
}

double StaleDetector::unchanged_ms(double now_ms) const {
  return last_ ? now_ms - changed_ms_ : 0;
}

std::optional<cv::Rect> find_video_area(const cv::Mat& frame) {
  if (frame.empty()) {
    return std::nullopt;
  }
  cv::Mat gray;
  cv::cvtColor(frame, gray, cv::COLOR_BGR2GRAY);
  cv::Mat edges;
  cv::Canny(gray, edges, kCannyLow, kCannyHigh);
  cv::dilate(edges, edges, cv::Mat());
  std::vector<std::vector<cv::Point>> contours;
  cv::findContours(edges, contours, cv::RETR_LIST, cv::CHAIN_APPROX_SIMPLE);
  std::optional<cv::Rect> best;
  for (const auto& contour : contours) {
    const cv::Rect box = bounding_rect(contour);
    const double area = box.area();
    if (!video_shaped(box, frame.size()) ||
        contour_area(contour) < kMinFill * area) {
      continue;
    }
    if (!best || area > best->area()) {
      best = box;
    }
  }
  return best;
}

void ChangeArea::add(const cv::Mat& frame) {
  if (frame.empty()) {
    return;
  }
  if (previous_.size() != frame.size() || previous_.type() != frame.type()) {
    previous_ = frame.clone();
    changed_ = cv::Mat::zeros(frame.size(), CV_8UC1);
    return;
  }
  cv::Mat difference;
  cv::absdiff(frame, previous_, difference);
  std::vector<cv::Mat> channels;
  cv::split(difference, channels);
  cv::Mat largest = channels.front();
  for (const cv::Mat& channel : channels) {
    largest = cv::max(largest, channel);
  }
  cv::Mat moved = largest > kChangeThreshold;
  changed_ |= moved;
  frame.copyTo(previous_);
}

std::optional<cv::Rect> ChangeArea::video_area() const {
  if (changed_.empty()) {
    return std::nullopt;
  }
  cv::Mat joined;
  cv::dilate(changed_, joined,
             cv::getStructuringElement(
                 cv::MORPH_RECT, {2 * kChangeJoin + 1, 2 * kChangeJoin + 1}));
  cv::Mat labels;
  cv::Mat stats;
  cv::Mat centroids;
  const int count =
      cv::connectedComponentsWithStats(joined, labels, stats, centroids);
  int best = 0;
  for (int i = 1; i < count; i++) {
    if (best == 0 || stats.at<int>(i, cv::CC_STAT_AREA) >
                         stats.at<int>(best, cv::CC_STAT_AREA)) {
      best = i;
    }
  }
  if (best == 0) {
    return std::nullopt;
  }
  const cv::Rect area =
      cv::Rect(stats.at<int>(best, cv::CC_STAT_LEFT) + kChangeJoin,
               stats.at<int>(best, cv::CC_STAT_TOP) + kChangeJoin,
               stats.at<int>(best, cv::CC_STAT_WIDTH) - 2 * kChangeJoin,
               stats.at<int>(best, cv::CC_STAT_HEIGHT) - 2 * kChangeJoin) &
      cv::Rect(0, 0, changed_.cols, changed_.rows);
  if (area.empty() || !video_shaped(area, changed_.size())) {
    return std::nullopt;
  }
  return area;
}

double visible_fraction(const cv::Rect2d& target,
                        const std::vector<ScreenWindow>& in_front) {
  if (target.width <= 0 || target.height <= 0) {
    return 0;
  }
  int visible = 0;
  for (int i = 0; i < kGrid; i++) {
    for (int j = 0; j < kGrid; j++) {
      const cv::Point2d point(target.x + target.width * (j + 0.5) / kGrid,
                              target.y + target.height * (i + 0.5) / kGrid);
      bool covered = false;
      for (const ScreenWindow& window : in_front) {
        covered = covered || window.bounds.contains(point);
      }
      visible += covered ? 0 : 1;
    }
  }
  return static_cast<double>(visible) / (kGrid * kGrid);
}

SourceStatus window_visibility(const cv::Rect2d& target, bool on_screen,
                               const std::vector<ScreenWindow>& in_front) {
  if (!on_screen) {
    return {SourceState::kHidden, "the window is not on screen"};
  }
  const double fraction = visible_fraction(target, in_front);
  if (fraction > 0) {
    char detail[32];
    std::snprintf(detail, sizeof detail, "%.0f%% of the window shows",
                  fraction * 100);
    return {SourceState::kLive, detail};
  }
  const ScreenWindow* most = nullptr;
  double most_area = 0;
  for (const ScreenWindow& window : in_front) {
    const double area = (window.bounds & target).area();
    if (area > most_area) {
      most = &window;
      most_area = area;
    }
  }
  return {SourceState::kCovered,
          most != nullptr ? "covered by " + most->owner : "covered"};
}

}  // namespace gamepilot
