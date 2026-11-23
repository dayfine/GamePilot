// Probes: pixels in, numbers out. No thresholds; the program judges the
// numbers.

#pragma once

#include <array>
#include <opencv2/core.hpp>
#include <string>
#include <string_view>
#include <vector>

namespace gamepilot {

// A box normalized to the frame: x, y, w, h in 0..1.
struct Box {
  double x = 0;
  double y = 0;
  double w = 0;
  double h = 0;
};

struct ColorStats {
  std::array<double, 3> mean{};    // r, g, b, 0..255
  std::array<double, 3> stddev{};  // r, g, b
};

inline constexpr std::string_view kColorStatsKind = "core.color_stats@1";

// The probe kinds this daemon evaluates, for hello and subscribe.
const std::vector<std::string>& probe_kinds();
bool is_known_probe_kind(std::string_view kind);

// The pixel rectangle a normalized box covers in a width x height frame: at
// least one pixel, clipped to the frame.
cv::Rect box_to_pixels(const Box& box, int width, int height);

// core.color_stats@1: per-channel mean and stddev of a BGR frame over the box.
ColorStats color_stats(const cv::Mat& bgr, const Box& box);

}  // namespace gamepilot
