// core.find@1: the fork's fixed blob pipeline on one box of a frame. Colour
// filter (one mask per RGB range, OpenCV inRange), then waterfill (4-connected
// components, as the fork's Kernels/Waterfill fills; OpenCV
// connectedComponentsWithStats), then a size filter, then per blob the scores
// a reader asked for. It mirrors CommonTools/Images/WaterfillUtilities.cpp
// (match_template_by_waterfill) and CommonTools/ImageMatch/
// WaterfillTemplateMatcher.cpp with ExactImageMatcher.cpp (the template
// score); the stray share and the shape overlap are the two blob tests of
// PokemonLZA_StoryDialogDetector.cpp (AdvanceArrowDetector) that a colour
// template cannot score. No thresholds: the reader judges every number.

#pragma once

#include <array>
#include <cstddef>
#include <opencv2/core.hpp>
#include <optional>
#include <string>
#include <vector>

#include "probes.h"

namespace gamepilot {

// A core.find@1 probe's params, in game pixels, as subscribed.
struct FindSpec {
  std::vector<ColorRange> filters;
  double min_area = 1;             // game pixels; a blob has at least this
  std::optional<double> max_area;  // and at most this, when given
  // Width and height bounds, game pixels, both ends included.
  std::optional<std::array<double, 2>> min_size;
  std::optional<std::array<double, 2>> max_size;
  std::optional<double> margin;  // game pixels: report each blob's stray
  std::string template_hash;     // non-empty: report each blob's score
  std::string shape_hash;        // non-empty: report each blob's overlap
  // Score each blob's box with the pixels outside the filter's range black,
  // as the fork's filter_by_mask before a match (MoveEffectivenessSymbol).
  bool masked = false;
};

// A FindSpec mapped onto frames of one size.
struct FrameFind {
  std::vector<ColorRange> filters;
  std::size_t min_area = 1;  // frame pixels
  std::size_t max_area = 0;  // frame pixels; 0 for no bound
  std::optional<std::array<double, 2>> min_size;  // game pixels
  std::optional<std::array<double, 2>> max_size;  // game pixels
  std::optional<int> margin;                      // frame pixels
  double x_scale = 1;                             // frame pixels per game pixel
  double y_scale = 1;
  cv::Mat template_bgra;  // the template as uploaded, with alpha; or empty
  cv::Mat shape;          // 8-bit, 255 on the shape's pixels; or empty
  bool masked = false;    // score the box with out-of-range pixels black
};

// Maps a spec onto frames whose game pixels are x_scale by y_scale frame
// pixels. Areas scale by both, truncated, and the margin by y_scale, rounded,
// as the fork scales its 1080p numbers by the frame's height over 1080.
// `template_bgra` and `shape_bgra` are the uploaded PNGs (empty when the spec
// names none); a shape's pixels are those with alpha 128 or more.
FrameFind map_find(const FindSpec& spec, double x_scale, double y_scale,
                   const cv::Mat& template_bgra, const cv::Mat& shape_bgra);

// Every blob of every filter inside `pixels`, in filter order, that passes the
// area and size filters, with the scores `find` asks for.
FindResult find_blobs(const cv::Mat& bgr, const cv::Rect& pixels,
                      const FrameFind& find);

// The fork's ExactImageMatcher::rmsd: `image` (BGR) resized to the template's
// size, the template's colours scaled by the ratio of the two images' mean
// colours over the template's opaque pixels (alpha 128 or more; each channel's
// ratio kept in 0.85..1.15), then the root mean square over those pixels of
// the summed squared channel differences.
double template_rmsd(const cv::Mat& image, const cv::Mat& template_bgra);

// The blob's pixels (`blob`, 8-bit, nonzero on the blob, its bounding box's
// size) against `shape` sampled at the centres of the box's pixels: pixels in
// both over pixels in either.
double shape_overlap(const cv::Mat& blob, const cv::Mat& shape);

}  // namespace gamepilot
