#include "blob_find.h"

#include <algorithm>
#include <cmath>
#include <opencv2/imgproc.hpp>

namespace gamepilot {

namespace {

// The fork's images keep alpha in the top byte; its kernels count a pixel as
// opaque when that byte's top bit is set (Kernels_ImagePixelSumSqr*).
constexpr int kOpaqueAlpha = 128;
// ExactImageMatcher::scale_template_brightness bounds each channel's ratio.
constexpr double kMinBrightness = 0.85;
constexpr double kMaxBrightness = 1.15;
constexpr int kChannelMax = 255;
constexpr int kConnectivity = 4;  // waterfill fills left, right, up, down

cv::Scalar bgr_of(const std::array<std::uint8_t, 3>& rgb) {
  return cv::Scalar(rgb[2], rgb[1], rgb[0]);
}

// The fork's ImageViewRGB32::scale_to on Qt: QImage::scaled with its default
// FastTransformation, nearest neighbour; OpenCV's INTER_NEAREST_EXACT samples
// at each pixel's centre as it does.
cv::Mat resized(const cv::Mat& image, cv::Size size) {
  if (image.size() == size) {
    return image;
  }
  cv::Mat out;
  cv::resize(image, out, size, 0, 0, cv::INTER_NEAREST_EXACT);
  return out;
}

// The template's opaque pixels as an 8-bit mask, 255 where alpha >= 128.
cv::Mat opaque_mask(const cv::Mat& bgra) {
  cv::Mat alpha;
  cv::extractChannel(bgra, alpha, 3);
  cv::Mat mask;
  cv::compare(alpha, kOpaqueAlpha, mask, cv::CMP_GE);
  return mask;
}

bool size_passes(const FrameFind& find, const cv::Rect& box) {
  const double width = box.width / find.x_scale;
  const double height = box.height / find.y_scale;
  if (find.min_size &&
      (width < (*find.min_size)[0] || height < (*find.min_size)[1])) {
    return false;
  }
  return !find.max_size ||
         (width <= (*find.max_size)[0] && height <= (*find.max_size)[1]);
}

// PokemonLZA_StoryDialogDetector.cpp's stray_share: the mask's pixels in the
// box grown by `margin` (clipped to the mask), less the blob's, over its area.
double stray_share(const cv::Mat& mask, const cv::Rect& box, int area,
                   int margin) {
  const cv::Rect grown(box.x - margin, box.y - margin, box.width + 2 * margin,
                       box.height + 2 * margin);
  const cv::Rect window = grown & cv::Rect(0, 0, mask.cols, mask.rows);
  const int in_window = cv::countNonZero(mask(window));
  return static_cast<double>(in_window - area) / area;
}

void add_blobs(const cv::Mat& area_bgr, const cv::Mat& mask, int filter,
               const FrameFind& find, const cv::Point& offset,
               std::vector<Blob>& blobs) {
  cv::Mat labels;
  cv::Mat stats;
  cv::Mat centroids;
  const int count = cv::connectedComponentsWithStats(
      mask, labels, stats, centroids, kConnectivity, CV_32S);
  for (int label = 1; label < count; label++) {
    const int area = stats.at<int>(label, cv::CC_STAT_AREA);
    const auto size = static_cast<std::size_t>(area);
    if (size < find.min_area || (find.max_area != 0 && size > find.max_area)) {
      continue;
    }
    const cv::Rect box(stats.at<int>(label, cv::CC_STAT_LEFT),
                       stats.at<int>(label, cv::CC_STAT_TOP),
                       stats.at<int>(label, cv::CC_STAT_WIDTH),
                       stats.at<int>(label, cv::CC_STAT_HEIGHT));
    if (!size_passes(find, box)) {
      continue;
    }
    Blob blob;
    blob.filter = filter;
    blob.box = box + offset;
    blob.area = area;
    if (find.margin) {
      blob.stray = stray_share(mask, box, area, *find.margin);
    }
    if (!find.template_bgra.empty()) {
      blob.score = template_rmsd(area_bgr(box), find.template_bgra);
    }
    if (!find.shape.empty()) {
      cv::Mat own;
      cv::compare(labels(box), label, own, cv::CMP_EQ);
      blob.overlap = shape_overlap(own, find.shape);
    }
    blobs.push_back(blob);
  }
}

}  // namespace

FrameFind map_find(const FindSpec& spec, double x_scale, double y_scale,
                   const cv::Mat& template_bgra, const cv::Mat& shape_bgra) {
  FrameFind find;
  find.filters = spec.filters;
  const double area_scale = x_scale * y_scale;
  find.min_area = static_cast<std::size_t>(area_scale * spec.min_area);
  if (spec.max_area) {
    find.max_area = static_cast<std::size_t>(area_scale * *spec.max_area);
  }
  find.min_size = spec.min_size;
  find.max_size = spec.max_size;
  if (spec.margin) {
    find.margin = static_cast<int>(*spec.margin * y_scale + 0.5);
  }
  find.x_scale = x_scale;
  find.y_scale = y_scale;
  find.template_bgra = template_bgra;
  if (!shape_bgra.empty()) {
    find.shape = opaque_mask(shape_bgra);
  }
  return find;
}

FindResult find_blobs(const cv::Mat& bgr, const cv::Rect& pixels,
                      const FrameFind& find) {
  const cv::Mat area = bgr(pixels);
  FindResult result;
  result.x_scale = find.x_scale;
  result.y_scale = find.y_scale;
  for (std::size_t i = 0; i < find.filters.size(); i++) {
    cv::Mat mask;
    cv::inRange(area, bgr_of(find.filters[i].min), bgr_of(find.filters[i].max),
                mask);
    add_blobs(area, mask, static_cast<int>(i), find, pixels.tl(), result.blobs);
  }
  return result;
}

double template_rmsd(const cv::Mat& image, const cv::Mat& template_bgra) {
  const cv::Mat scaled = resized(image, template_bgra.size());
  const cv::Mat opaque = opaque_mask(template_bgra);
  cv::Mat template_bgr;
  cv::cvtColor(template_bgra, template_bgr, cv::COLOR_BGRA2BGR);
  const cv::Scalar image_mean = cv::mean(scaled, opaque);
  const cv::Scalar template_mean = cv::mean(template_bgr, opaque);
  // FloatPixel's ratio: 0/0 (NaN) counts as 1, anything else is bounded.
  std::array<float, 3> ratio{};
  for (int c = 0; c < 3; c++) {
    double r = image_mean[c] / template_mean[c];
    if (std::isnan(r)) {
      r = 1;
    }
    ratio[static_cast<std::size_t>(c)] =
        static_cast<float>(std::clamp(r, kMinBrightness, kMaxBrightness));
  }
  double sum = 0;
  int count = 0;
  for (int y = 0; y < scaled.rows; y++) {
    for (int x = 0; x < scaled.cols; x++) {
      if (opaque.at<std::uint8_t>(y, x) == 0) {
        continue;
      }
      count++;
      const cv::Vec3b& seen = scaled.at<cv::Vec3b>(y, x);
      const cv::Vec3b& drawn = template_bgr.at<cv::Vec3b>(y, x);
      for (int c = 0; c < 3; c++) {
        // Kernels_ImageScaleBrightness_Default.cpp: float, + 0.5, capped.
        const float scaled_channel =
            static_cast<float>(drawn[c]) * ratio[static_cast<std::size_t>(c)];
        const int reference =
            std::min(static_cast<int>(scaled_channel + 0.5F), kChannelMax);
        const int difference = reference - seen[c];
        sum += static_cast<double>(difference) * difference;
      }
    }
  }
  return count == 0 ? 0 : std::sqrt(sum / count);
}

double shape_overlap(const cv::Mat& blob, const cv::Mat& shape) {
  const cv::Mat sampled = resized(shape, blob.size());
  cv::Mat both;
  cv::Mat either;
  cv::bitwise_and(blob != 0, sampled != 0, both);
  cv::bitwise_or(blob != 0, sampled != 0, either);
  const int union_pixels = cv::countNonZero(either);
  return union_pixels == 0
             ? 0
             : static_cast<double>(cv::countNonZero(both)) / union_pixels;
}

}  // namespace gamepilot
