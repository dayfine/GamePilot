#include "press_latency.h"

#include <algorithm>
#include <cmath>
#include <optional>

namespace gamepilot {

namespace {

// Longest wait for one frame before checking the clock again.
constexpr double kFrameWaitMs = 50;

double mean_abs_difference(const cv::Mat& a, const cv::Mat& b,
                           const cv::Rect& rect) {
  cv::Mat diff;
  cv::absdiff(a(rect), b(rect), diff);
  const cv::Scalar mean = cv::mean(diff);
  return (mean[0] + mean[1] + mean[2]) / 3.0;
}

// Takes frames until `until_ms`; returns the last one, if any came.
std::optional<cv::Mat> drain_until(Backend& backend, const Clock& clock,
                                   double until_ms) {
  std::optional<cv::Mat> last;
  while (clock.now_ms() < until_ms) {
    if (backend.next_frame(std::min(kFrameWaitMs, until_ms - clock.now_ms()))) {
      last = backend.frame().clone();
    }
  }
  return last;
}

// The capture time of the first frame from `pressed_ms` on that differs from
// `before` inside `rect`, or nullopt by `deadline_ms`.
std::optional<double> first_change(Backend& backend, const Clock& clock,
                                   const cv::Mat& before, const cv::Rect& rect,
                                   double threshold, double pressed_ms,
                                   double deadline_ms) {
  while (clock.now_ms() < deadline_ms) {
    const auto stamp = backend.next_frame(kFrameWaitMs);
    if (!stamp || stamp->t_ms < pressed_ms) {
      continue;
    }
    if (mean_abs_difference(backend.frame(), before, rect) >= threshold) {
      return stamp->t_ms;
    }
  }
  return std::nullopt;
}

}  // namespace

PressLatencyReport measure_press_latency(Backend& backend, const Clock& clock,
                                         const PressLatencyPlan& plan) {
  const BackendInfo& info = backend.info();
  const cv::Rect rect = box_to_pixels(plan.box, info.width, info.height);
  PressLatencyReport report;
  report.frame_ms = 1000.0 / info.frame_rate;
  for (int i = 0; i < plan.presses; i++) {
    const std::optional<cv::Mat> before =
        drain_until(backend, clock, clock.now_ms() + plan.settle_ms);
    if (!before) {
      throw BackendError("no frames while settling");
    }
    const double pressed_ms = clock.now_ms();
    backend.queue_keys(plan.keys, Sticks{}, plan.hold_ms);
    backend.queue_keys(0, Sticks{}, 0);
    const std::optional<double> changed =
        first_change(backend, clock, *before, rect, plan.threshold, pressed_ms,
                     pressed_ms + plan.timeout_ms);
    if (changed) {
      report.latencies_ms.push_back(*changed - pressed_ms);
    } else {
      report.misses++;
    }
  }
  return report;
}

double percentile(std::vector<double> values, double q) {
  if (values.empty()) {
    return 0;
  }
  std::sort(values.begin(), values.end());
  const auto rank = static_cast<std::size_t>(
      std::ceil(q * static_cast<double>(values.size())));
  return values[std::clamp<std::size_t>(rank, 1, values.size()) - 1];
}

}  // namespace gamepilot
