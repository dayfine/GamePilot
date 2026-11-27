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

// The best placement of a template inside a box, scored with TM_CCOEFF_NORMED
// on grayscale (higher is better, -1..1).
struct TemplateNcc {
  double score = 0;
  // Top-left corner of the placement: frame pixels from template_ncc,
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

// One linear comparison on a pixel's channels:
// weights[0] * r + weights[1] * g + weights[2] * b <op> value, in integers.
// The fork's PixelShares tests (PokemonLZA_PixelShares.cpp,
// PokemonLZA_ControlsHintDetector.cpp) are conjunctions of these, e.g.
// b > r + 60 is {-1, 0, 1} > 60.
struct ChannelComparison {
  enum class Op { kGreater, kGreaterEqual, kLess, kLessEqual };
  std::array<int, 3> weights{};  // r, g, b
  Op op = Op::kGreater;
  int value = 0;
};

// A pixel passes when every comparison holds (none: every pixel passes).
using PixelTest = std::vector<ChannelComparison>;

// The share of a box's pixels that pass a PixelTest, per row (top to bottom)
// and per column (left to right) of the box's frame pixels.
struct LineShares {
  std::vector<double> rows;
  std::vector<double> columns;
};

// One blob of core.find@1: a 4-connected region of pixels in one filter's
// range, as the fork's waterfill finds them. Geometry is in frame pixels here;
// the probe result converts it to game pixels.
struct Blob {
  int filter = 0;  // the index of the filter whose range made it
  cv::Rect box;    // its bounding box, frame pixels
  int area = 0;    // its pixels
  // With a margin: the filter's pixels within the margin around the box
  // (clipped to the probe's box) and not in the blob, over area.
  std::optional<double> stray;
  // With a template: the fork's ExactImageMatcher::rmsd of the box's pixels.
  std::optional<double> score;
  // With a shape: the blob's overlap with the shape over their union.
  std::optional<double> overlap;
};

struct FindResult {
  std::vector<Blob> blobs;
  // Frame pixels per game pixel, to report blobs in game pixels.
  double x_scale = 1;
  double y_scale = 1;
  // The picture's top-left corner in frame pixels.
  double picture_x = 0;
  double picture_y = 0;
};

using ProbeResult =
    std::variant<ColorStats, TemplateMatch, TemplateNcc, ColorCount, LineShares,
                 FindResult>;

inline constexpr std::string_view kColorStatsKind = "core.color_stats@1";
inline constexpr std::string_view kTemplateMatchKind = "core.template_match@1";
inline constexpr std::string_view kTemplateNccKind = "core.template_ncc@1";
inline constexpr std::string_view kColorCountKind = "core.color_count@1";
inline constexpr std::string_view kLineSharesKind = "core.line_shares@1";
inline constexpr std::string_view kFindKind = "core.find@1";

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
// With `compared` (a one-channel CV_8U mask of the template's size, 1 for a
// pixel compared, 0 for one left out), only those pixels count and the score
// divides by their number instead of w * h.
TemplateMatch template_match(const cv::Mat& image,
                             const cv::Mat& template_image,
                             const cv::Rect& pixels,
                             const cv::Mat& compared = cv::Mat());

// core.template_ncc@1: best grayscale zero-mean normalized cross-correlation
// (OpenCV TM_CCOEFF_NORMED) of a one-channel grayscale template inside `pixels`
// of a BGR frame. Score is clamped to [-1, 1] (0 if non-finite). x, y are frame
// pixels.
TemplateNcc template_ncc(const cv::Mat& bgr, const cv::Mat& template_gray,
                         const cv::Rect& pixels);

// The pixels of a BGR image inside the ink range as an 8-bit mask: 255 where
// every channel is in range, 0 elsewhere.
cv::Mat ink_mask(const cv::Mat& bgr, const ColorRange& ink);

// core.template_match@1 with ink: template_match of the box's ink mask against
// a template mask (ink_mask of the template, then scaled). With binary masks
// the score is the fraction of template pixels whose mask differs.
// `compared` as for template_match.
TemplateMatch mask_match(const cv::Mat& bgr, const cv::Mat& template_mask,
                         const cv::Rect& pixels, const ColorRange& ink,
                         const cv::Mat& compared = cv::Mat());

// The whole pixels of a scaled template mask, for skip_seams: 1 where the mask
// is 0 or 255, 0 on a seam pixel, which straddles two game pixels and holds a
// blend. A binary box mask can only half agree with a blend, so a seam costs
// about 1/4 whatever the frame shows there.
cv::Mat whole_pixels(const cv::Mat& template_mask);

// core.color_count@1: how many of the pixels lie inside the range, and their
// mean color.
ColorCount color_count(const cv::Mat& bgr, const cv::Rect& pixels,
                       const ColorRange& range);

// Whether a pixel's channels (r, g, b) pass every comparison.
bool passes(const PixelTest& test, int r, int g, int b);

// core.line_shares@1: the share of the pixels passing `test`, per row and per
// column of the box.
LineShares line_shares(const cv::Mat& bgr, const cv::Rect& pixels,
                       const PixelTest& test);

// A template (BGR or a mask) given in game pixels, resized to `size` frame
// pixels with INTER_AREA (unchanged when it already has that size).
cv::Mat scale_template(const cv::Mat& template_image, cv::Size size);

}  // namespace gamepilot
