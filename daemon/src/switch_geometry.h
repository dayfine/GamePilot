// Whether a Switch capture shows the game picture where the viewport says: the
// frame's lit rows and columns (bright on average) fit the picture box, give or
// take the scaler's bleed, and span most of it. A wrong box (another app,
// another resolution, a frame cropped by the card) lights rows or columns
// outside it or leaves it half dark.
// Used by --capture-check on the console and by switch_geometry_test on the
// lab's captures.

#pragma once

#include <opencv2/core.hpp>
#include <string>

#include "viewport.h"

namespace gamepilot {

struct GeometryCheck {
  bool ok = false;
  cv::Rect picture;  // the viewport's picture, in frame pixels
  cv::Rect lit;      // the lit rows and columns' span (empty: none)
};

// `picture` is the game picture normalized to the frame (Viewport::picture).
GeometryCheck check_geometry(const cv::Mat& frame, const Box& picture);

std::string describe(const GeometryCheck& check);

// Writes `frame` to `path` as a PNG. Throws BackendError on failure.
void save_png(const std::string& path, const cv::Mat& frame);

}  // namespace gamepilot
