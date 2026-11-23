// Probes: pixels in, numbers out, on a pixel rectangle of a BGR frame. No
// thresholds; the program judges the numbers. Mapping a client's box onto the
// frame is probe_evaluation's job.

#pragma once

#include <array>
#include <cstdint>
#include <opencv2/core.hpp>
#include <optional>
#include <string>
#include <string_view>
#include <variant>
#include <vector>

#include "viewport.h"

namespace gamepilot {

struct ColorStats {
  std::array<double, 3> mean{};    // r, g, b, 0..255
  std::array<double, 3> stddev{};  // r, g, b
};

// The best placement of a template inside a box.
struct TemplateMatch {
  // Mean squared difference per pixel and channel, divided by 255^2: 0 for
  // identical pixels, 1 for every channel as far off as it can be.
  double score = 0;
  // Top-left corner of the placement: frame pixels from template_match,
  // normalized to the game picture in a probe result.
  double x = 0;
  double y = 0;
};

// An inclusive per-channel range: r, g, b, 0..255.
struct ColorRange {
  std::array<std::uint8_t, 3> min{};
  std::array<std::uint8_t, 3> max{};
};

// The pixels of a box inside a color range.
struct ColorCount {
  double fraction = 0;  // pixels in range / pixels in the box
  // r, g, b mean of the pixels in range; nullopt when there are none.
  std::optional<std::array<double, 3>> mean;
};

using ProbeResult = std::variant<ColorStats, TemplateMatch, ColorCount>;

inline constexpr std::string_view kColorStatsKind = "core.color_stats@1";
inline constexpr std::string_view kTemplateMatchKind = "core.template_match@1";
inline constexpr std::string_view kColorCountKind = "core.color_count@1";

// The probe kinds this daemon evaluates, for hello and subscribe.
const std::vector<std::string>& probe_kinds();
bool is_known_probe_kind(std::string_view kind);

// core.color_stats@1: per-channel mean and stddev of a BGR frame over the
// pixels.
ColorStats color_stats(const cv::Mat& bgr, const cv::Rect& pixels);

// core.template_match@1: the template's best placement fully inside the pixels
// (which must be at least the template's size), scored with OpenCV TM_SQDIFF /
// (w * h * channels * 255^2). The image and the template have the same
// channels: BGR, or one for masks. x, y are frame pixels. Not TM_SQDIFF_NORMED:
// that divides by the template's energy and scores a flat black template 1 on
// an exact match.
TemplateMatch template_match(const cv::Mat& image,
                             const cv::Mat& template_image,
                             const cv::Rect& pixels);

// The pixels of a BGR image inside the ink range as an 8-bit mask: 255 where
// every channel is in range, 0 elsewhere.
cv::Mat ink_mask(const cv::Mat& bgr, const ColorRange& ink);

// core.template_match@1 with ink: template_match of the box's ink mask against
// a template mask (ink_mask of the template, then scaled). With binary masks
// the score is the fraction of template pixels whose mask differs.
TemplateMatch mask_match(const cv::Mat& bgr, const cv::Mat& template_mask,
                         const cv::Rect& pixels, const ColorRange& ink);

// core.color_count@1: how many of the pixels lie inside the range, and their
// mean color.
ColorCount color_count(const cv::Mat& bgr, const cv::Rect& pixels,
                       const ColorRange& range);

// A template (BGR or a mask) given in game pixels, resized to `size` frame
// pixels with INTER_AREA (unchanged when it already has that size).
cv::Mat scale_template(const cv::Mat& template_image, cv::Size size);

}  // namespace gamepilot
