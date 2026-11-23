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
      std::string(kColorCountKind)};
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

TemplateMatch template_match(const cv::Mat& bgr, const cv::Mat& template_bgr,
                             const cv::Rect& pixels) {
  constexpr double kChannelMax = 255;
  cv::Mat differences;
  cv::matchTemplate(bgr(pixels), template_bgr, differences, cv::TM_SQDIFF);
  double min_difference = 0;
  cv::Point best;
  cv::minMaxLoc(differences, &min_difference, nullptr, &best, nullptr);
  const double samples =
      static_cast<double>(template_bgr.total()) * template_bgr.channels();
  TemplateMatch match;
  // OpenCV may sum in the frequency domain and land a hair below 0.
  match.score = std::clamp(
      min_difference / (samples * kChannelMax * kChannelMax), 0.0, 1.0);
  match.x = pixels.x + best.x;
  match.y = pixels.y + best.y;
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

cv::Mat scale_template(const cv::Mat& template_bgr, cv::Size size) {
  if (template_bgr.size() == size) {
    return template_bgr;
  }
  cv::Mat scaled;
  cv::resize(template_bgr, scaled, size, 0, 0, cv::INTER_AREA);
  return scaled;
}

}  // namespace gamepilot
