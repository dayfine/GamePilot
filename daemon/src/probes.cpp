#include "probes.h"

#include <algorithm>
#include <cmath>
#include <opencv2/imgproc.hpp>

namespace gamepilot {

namespace {

// OpenCV channels are B, G, R; results are R, G, B.
std::array<double, 3> rgb_of(const cv::Scalar& bgr) {
  return {bgr[2], bgr[1], bgr[0]};
}

cv::Scalar bgr_of(const std::array<std::uint8_t, 3>& rgb) {
  return cv::Scalar(rgb[2], rgb[1], rgb[0]);
}

}  // namespace

const std::vector<std::string>& probe_kinds() {
  static const std::vector<std::string> kinds = {
      std::string(kColorStatsKind), std::string(kTemplateMatchKind),
      std::string(kColorCountKind), std::string(kLineSharesKind),
      std::string(kFindKind)};
  return kinds;
}

bool is_known_probe_kind(std::string_view kind) {
  const auto& kinds = probe_kinds();
  return std::find(kinds.begin(), kinds.end(), kind) != kinds.end();
}

ColorStats color_stats(const cv::Mat& bgr, const cv::Rect& pixels) {
  cv::Scalar mean;
  cv::Scalar stddev;
  cv::meanStdDev(bgr(pixels), mean, stddev);
  return ColorStats{rgb_of(mean), rgb_of(stddev)};
}

TemplateMatch template_match(const cv::Mat& image,
                             const cv::Mat& template_image,
                             const cv::Rect& pixels) {
  constexpr double kChannelMax = 255;
  cv::Mat differences;
  cv::matchTemplate(image(pixels), template_image, differences, cv::TM_SQDIFF);
  double min_difference = 0;
  cv::Point best;
  cv::minMaxLoc(differences, &min_difference, nullptr, &best, nullptr);
  const double samples =
      static_cast<double>(template_image.total()) * template_image.channels();
  TemplateMatch match;
  // OpenCV may sum in the frequency domain and land a hair below 0.
  match.score = std::clamp(
      min_difference / (samples * kChannelMax * kChannelMax), 0.0, 1.0);
  match.x = pixels.x + best.x;
  match.y = pixels.y + best.y;
  return match;
}

cv::Mat ink_mask(const cv::Mat& bgr, const ColorRange& ink) {
  cv::Mat mask;
  cv::inRange(bgr, bgr_of(ink.min), bgr_of(ink.max), mask);
  return mask;
}

TemplateMatch mask_match(const cv::Mat& bgr, const cv::Mat& template_mask,
                         const cv::Rect& pixels, const ColorRange& ink) {
  const cv::Mat box_mask = ink_mask(bgr(pixels), ink);
  TemplateMatch match = template_match(
      box_mask, template_mask, cv::Rect(0, 0, pixels.width, pixels.height));
  match.x += pixels.x;
  match.y += pixels.y;
  return match;
}

ColorCount color_count(const cv::Mat& bgr, const cv::Rect& pixels,
                       const ColorRange& range) {
  const cv::Mat region = bgr(pixels);
  cv::Mat in_range;
  cv::inRange(region, bgr_of(range.min), bgr_of(range.max), in_range);
  const int count = cv::countNonZero(in_range);
  ColorCount result;
  result.fraction = static_cast<double>(count) / pixels.area();
  if (count > 0) {
    result.mean = rgb_of(cv::mean(region, in_range));
  }
  return result;
}

bool passes(const PixelTest& test, int r, int g, int b) {
  for (const ChannelComparison& comparison : test) {
    const int sum = comparison.weights[0] * r + comparison.weights[1] * g +
                    comparison.weights[2] * b;
    bool holds = false;
    switch (comparison.op) {
      case ChannelComparison::Op::kGreater:
        holds = sum > comparison.value;
        break;
      case ChannelComparison::Op::kGreaterEqual:
        holds = sum >= comparison.value;
        break;
      case ChannelComparison::Op::kLess:
        holds = sum < comparison.value;
        break;
      case ChannelComparison::Op::kLessEqual:
        holds = sum <= comparison.value;
        break;
    }
    if (!holds) {
      return false;
    }
  }
  return true;
}

LineShares line_shares(const cv::Mat& bgr, const cv::Rect& pixels,
                       const PixelTest& test) {
  const cv::Mat region = bgr(pixels);
  std::vector<int> per_row(static_cast<std::size_t>(region.rows), 0);
  std::vector<int> per_column(static_cast<std::size_t>(region.cols), 0);
  for (int y = 0; y < region.rows; y++) {
    const auto* row = region.ptr<cv::Vec3b>(y);
    for (int x = 0; x < region.cols; x++) {
      const cv::Vec3b& pixel = row[x];
      if (passes(test, pixel[2], pixel[1], pixel[0])) {
        per_row[static_cast<std::size_t>(y)]++;
        per_column[static_cast<std::size_t>(x)]++;
      }
    }
  }
  LineShares shares;
  for (const int count : per_row) {
    shares.rows.push_back(static_cast<double>(count) / region.cols);
  }
  for (const int count : per_column) {
    shares.columns.push_back(static_cast<double>(count) / region.rows);
  }
  return shares;
}

cv::Mat scale_template(const cv::Mat& template_image, cv::Size size) {
  if (template_image.size() == size) {
    return template_image;
  }
  cv::Mat scaled;
  cv::resize(template_image, scaled, size, 0, 0, cv::INTER_AREA);
  return scaled;
}

}  // namespace gamepilot
