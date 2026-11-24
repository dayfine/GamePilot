// What a view-only source (view_backend.h) knows about its picture: whether it
// is live, stale (the same picture for a while: a frozen window, a paused
// video) or covered (the window is behind others, so its app stops painting),
// and where the video sits in a captured window. Pure functions and small
// state, no capture: the window capture (window_capture.h) and the backend use
// them, and the tests check them on plain images and rectangles.

#pragma once

#include <cstdint>
#include <opencv2/core.hpp>
#include <optional>
#include <string>
#include <vector>

namespace gamepilot {

enum class SourceState { kLive, kStale, kCovered, kHidden };

// "live", "stale", "covered", "hidden".
const char* source_state_name(SourceState state);

struct SourceStatus {
  SourceState state = SourceState::kLive;
  std::string detail;  // for people: "covered by Terminal", "12 s unchanged"

  bool operator==(const SourceStatus&) const = default;
};

// {"state": ..., "detail": ...}, one line: the page's `source` event and
// /summary.json's `source`.
std::string source_status_json(const SourceStatus& status);

// A cheap fingerprint of a frame's pixels: every few pixels' green channel.
// Two frames with the same picture give the same value.
std::uint64_t frame_fingerprint(const cv::Mat& frame);

// Stale once no frame changed the fingerprint for `stale_after_ms` (frames that
// stop coming count as unchanged too).
class StaleDetector {
 public:
  explicit StaleDetector(double stale_after_ms)
      : stale_after_ms_(stale_after_ms) {}

  void frame(std::uint64_t fingerprint, double now_ms);
  // How long the picture has not changed; 0 before the first frame.
  double unchanged_ms(double now_ms) const;
  bool stale(double now_ms) const {
    return unchanged_ms(now_ms) >= stale_after_ms_;
  }

 private:
  double stale_after_ms_;
  std::optional<std::uint64_t> last_;
  double changed_ms_ = 0;
};

// The largest rectangle in `frame` (BGR) whose sides are edges and whose
// aspect is 16:9 within 3 %, at least a tenth of the frame's area: the video
// widget in an app's window. Nothing when there is none. It needs the
// picture's border to stand out all round (on PA/CC: a bright scene); a dark
// scene with overlay boxes defeats it, and ChangeArea finds it then.
std::optional<cv::Rect> find_video_area(const cv::Mat& frame);

// The video in a window found by what moves: the app's UI around it stays
// still, the picture changes. Frames of one size are added a few times a
// second; the largest connected area that changed in any of them is the video
// once it is 16:9 (as find_video_area).
class ChangeArea {
 public:
  // Starts over when the frame size changes.
  void add(const cv::Mat& frame);
  std::optional<cv::Rect> video_area() const;

 private:
  cv::Mat previous_;
  cv::Mat changed_;  // 255 where a pixel changed between two frames added
};

// A window on screen, in screen points.
struct ScreenWindow {
  cv::Rect2d bounds;
  std::string owner;  // its app's name
};

// How much of `target` the windows in front of it leave visible, 0..1,
// sampled on a 32 x 32 grid.
double visible_fraction(const cv::Rect2d& target,
                        const std::vector<ScreenWindow>& in_front);

// From the window list (front to back, only normal windows, the target
// included): covered when nothing of the target shows ("covered by" the
// front window over most of it), else live with how much shows. Hidden when
// the target is not on screen (minimised, another Space).
SourceStatus window_visibility(const cv::Rect2d& target, bool on_screen,
                               const std::vector<ScreenWindow>& in_front);

}  // namespace gamepilot
