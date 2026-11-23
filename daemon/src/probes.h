// Probes: pixels in, numbers out. No thresholds; the program judges the
// numbers.

#pragma once

#include <array>
#include <opencv2/core.hpp>
#include <string>
#include <string_view>
#include <variant>
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

// The best placement of a template inside a box.
struct TemplateMatch {
  // Mean squared difference per pixel and channel, divided by 255^2: 0 for
  // identical pixels, 1 for every channel as far off as it can be.
  double score = 0;
  // Top-left corner of the placement, normalized to the frame.
  double x = 0;
  double y = 0;
};

using ProbeResult = std::variant<ColorStats, TemplateMatch>;

inline constexpr std::string_view kColorStatsKind = "core.color_stats@1";
inline constexpr std::string_view kTemplateMatchKind = "core.template_match@1";

// The probe kinds this daemon evaluates, for hello and subscribe.
const std::vector<std::string>& probe_kinds();
bool is_known_probe_kind(std::string_view kind);

// The pixel rectangle a normalized box covers in a width x height frame: at
// least one pixel, clipped to the frame.
cv::Rect box_to_pixels(const Box& box, int width, int height);

// core.color_stats@1: per-channel mean and stddev of a BGR frame over the box.
ColorStats color_stats(const cv::Mat& bgr, const Box& box);

// Whether a BGR template fits inside the box's pixels in a width x height
// frame, as template_match requires.
bool template_fits_box(const cv::Mat& template_bgr, const Box& box, int width,
                       int height);

// core.template_match@1: the template's best placement fully inside the box,
// scored with OpenCV TM_SQDIFF / (w * h * 3 * 255^2). Requires
// template_fits_box. Not TM_SQDIFF_NORMED: that divides by the template's
// energy and scores a flat black template 1 on an exact match.
TemplateMatch template_match(const cv::Mat& bgr, const cv::Mat& template_bgr,
                             const Box& box);

}  // namespace gamepilot
