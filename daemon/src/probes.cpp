#include "probes.h"

#include <algorithm>
#include <cmath>
#include <opencv2/imgproc.hpp>

namespace gamepilot {

const std::vector<std::string>& probe_kinds() {
  static const std::vector<std::string> kinds = {
      std::string(kColorStatsKind), std::string(kTemplateMatchKind)};
  return kinds;
}

bool is_known_probe_kind(std::string_view kind) {
  const auto& kinds = probe_kinds();
  return std::find(kinds.begin(), kinds.end(), kind) != kinds.end();
}

cv::Rect box_to_pixels(const Box& box, int width, int height) {
  const auto edge = [](double fraction, int size) {
    return std::clamp(static_cast<int>(std::lround(fraction * size)), 0, size);
  };
  int x0 = edge(box.x, width);
  int y0 = edge(box.y, height);
  int x1 = edge(box.x + box.w, width);
  int y1 = edge(box.y + box.h, height);
  x0 = std::min(x0, width - 1);
  y0 = std::min(y0, height - 1);
  x1 = std::max(x1, x0 + 1);
  y1 = std::max(y1, y0 + 1);
  return cv::Rect(x0, y0, x1 - x0, y1 - y0);
}

ColorStats color_stats(const cv::Mat& bgr, const Box& box) {
  const cv::Mat region = bgr(box_to_pixels(box, bgr.cols, bgr.rows));
  cv::Scalar mean;
  cv::Scalar stddev;
  cv::meanStdDev(region, mean, stddev);
  ColorStats stats;
  for (int c = 0; c < 3; c++) {
    // OpenCV channels are B, G, R; results are R, G, B.
    stats.mean[static_cast<std::size_t>(c)] = mean[2 - c];
    stats.stddev[static_cast<std::size_t>(c)] = stddev[2 - c];
  }
  return stats;
}

bool template_fits_box(const cv::Mat& template_bgr, const Box& box, int width,
                       int height) {
  const cv::Rect pixels = box_to_pixels(box, width, height);
  return template_bgr.cols <= pixels.width &&
         template_bgr.rows <= pixels.height;
}

TemplateMatch template_match(const cv::Mat& bgr, const cv::Mat& template_bgr,
                             const Box& box) {
  constexpr double kChannelMax = 255;
  const cv::Rect pixels = box_to_pixels(box, bgr.cols, bgr.rows);
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
  match.x = static_cast<double>(pixels.x + best.x) / bgr.cols;
  match.y = static_cast<double>(pixels.y + best.y) / bgr.rows;
  return match;
}

}  // namespace gamepilot
