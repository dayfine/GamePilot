// Where the game picture sits in a backend's frames, and how big it is in the
// game's own pixels. Probe boxes are relative to the picture and templates are
// in game pixels, so a client's numbers mean the same on every backend; the
// daemon maps them onto the frame here.

#pragma once

#include <opencv2/core.hpp>
#include <optional>
#include <string_view>

namespace gamepilot {

// A box normalized to a rectangle (the frame, or the game picture in it): x, y,
// w, h in 0..1.
struct Box {
  double x = 0;
  double y = 0;
  double w = 0;
  double h = 0;
};

struct Viewport {
  // The game picture inside the frame, normalized to the frame. mGBA frames
  // are the picture itself; a capture card frame has it inside side bars.
  Box picture{0, 0, 1, 1};
  // The picture's native size in game pixels (240 x 160 on the GBA).
  int game_width = 0;
  int game_height = 0;
};

// Whether the box lies in 0..1 with w, h > 0.
bool is_unit_box(const Box& box);

// `box`, relative to the game picture, as a box normalized to the frame.
Box picture_box_to_frame(const Viewport& viewport, const Box& box);

// A frame-normalized x (or y) as a fraction of the picture's width (height).
double frame_x_to_picture(const Viewport& viewport, double x);
double frame_y_to_picture(const Viewport& viewport, double y);

// The pixel rectangle a frame-normalized box covers in a width x height frame:
// at least one pixel, clipped to the frame.
cv::Rect box_to_pixels(const Box& box, int width, int height);

// The size in frame pixels of a w x h template given in game pixels, in a
// width x height frame: w and h times the frame pixels per game pixel, rounded,
// at least 1.
cv::Size template_size_in_frame(const Viewport& viewport, cv::Size game_size,
                                int width, int height);

// "x,y,w,h" as a box when it is_unit_box, else nullopt.
std::optional<Box> parse_box(std::string_view text);

}  // namespace gamepilot
