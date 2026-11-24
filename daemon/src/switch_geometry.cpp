#include "switch_geometry.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>
#include <cstdint>
#include <utility>
#include <vector>

#include "Common/Cpp/Exceptions.h"
#include "Common/Cpp/Filesystem/FileIO.h"
#include "backend.h"

namespace gamepilot {

namespace {

// A row (column) of the frame is lit when its pixels' channels sum to more
// than this on average: the bars of the Switch's GBA app average 15-45 on the
// lab's captures (compression noise and the scaler's bleed), a row or column
// through the picture 300 and up.
constexpr double kLitMean = 100;
// How far the scaler's bleed reaches past the picture on the lab's captures
// (lit columns from 176 where the picture starts at 180).
constexpr int kBleedPixels = 4;
// The lit span must cover this share of the picture each way (0.98 on the
// darkest lab capture, a text box against the right edge).
constexpr double kMinFill = 0.9;

// The first and last index above kLitMean of a 1-D profile, or -1s.
std::pair<int, int> lit_span(const cv::Mat& profile) {
  const cv::Mat flat = profile.reshape(1, 1);
  int first = -1;
  int last = -1;
  for (int i = 0; i < flat.cols; i++) {
    if (flat.at<float>(0, i) > kLitMean) {
      first = first < 0 ? i : first;
      last = i;
    }
  }
  return {first, last};
}

// The box spanned by the lit rows and columns of a channel-sum image (empty:
// none).
cv::Rect lit_box(const cv::Mat& sum) {
  cv::Mat columns;
  cv::Mat rows;
  cv::reduce(sum, columns, 0, cv::REDUCE_AVG);
  cv::reduce(sum, rows, 1, cv::REDUCE_AVG);
  const auto [left, right] = lit_span(columns);
  const auto [top, bottom] = lit_span(rows);
  if (left < 0 || top < 0) {
    return {};
  }
  return {left, top, right - left + 1, bottom - top + 1};
}

std::string rect_text(const cv::Rect& rect) {
  return std::to_string(rect.width) + "x" + std::to_string(rect.height) +
         " at (" + std::to_string(rect.x) + ", " + std::to_string(rect.y) + ")";
}

}  // namespace

GeometryCheck check_geometry(const cv::Mat& frame, const Box& picture) {
  GeometryCheck check;
  check.picture = box_to_pixels(picture, frame.cols, frame.rows);
  std::vector<cv::Mat> channels;
  cv::split(frame, channels);
  cv::Mat sum = cv::Mat::zeros(frame.size(), CV_32F);
  for (std::size_t c = 0; c < channels.size() && c < 3; c++) {
    cv::Mat channel;
    channels[c].convertTo(channel, CV_32F);
    sum += channel;
  }
  check.lit = lit_box(sum);
  const cv::Rect allowed(check.picture.x - kBleedPixels,
                         check.picture.y - kBleedPixels,
                         check.picture.width + 2 * kBleedPixels,
                         check.picture.height + 2 * kBleedPixels);
  check.ok = !check.lit.empty() && (check.lit & allowed) == check.lit &&
             check.lit.width >= kMinFill * check.picture.width &&
             check.lit.height >= kMinFill * check.picture.height;
  return check;
}

std::string describe(const GeometryCheck& check) {
  return std::string(check.ok ? "geometry ok" : "geometry WRONG") +
         ": picture " + rect_text(check.picture) + ", lit " +
         (check.lit.empty() ? std::string("nothing") : rect_text(check.lit));
}

void save_png(const std::string& path, const cv::Mat& frame) {
  std::vector<unsigned char> bytes;
  if (!cv::imencode(".png", frame, bytes)) {
    throw BackendError("cannot encode the frame as PNG");
  }
  try {
    PokemonAutomation::string_to_file(path,
                                      std::string(bytes.begin(), bytes.end()));
  } catch (const PokemonAutomation::Exception& e) {
    throw BackendError("cannot write " + path + ": " + e.message());
  }
}

}  // namespace gamepilot
