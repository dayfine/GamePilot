#include "viewport.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdlib>
#include <string>

namespace gamepilot {

Viewport nso_gba_viewport() {
  // The fork's FRLG GAME_BOX as written (1560 x 1040 at (180, 5) of 1920 x
  // 1080, to 1e-6); the reader fixtures are probed with exactly these numbers.
  constexpr Box kGameBox{0.09375, 0.00462963, 0.8125, 0.962963};
  constexpr int kGbaWidth = 240;
  constexpr int kGbaHeight = 160;
  return Viewport{kGameBox, kGbaWidth, kGbaHeight};
}

Viewport native_switch_viewport() {
  constexpr int kWidth = 1920;
  constexpr int kHeight = 1080;
  return Viewport{Box{0, 0, 1, 1}, kWidth, kHeight};
}

std::optional<Viewport> named_viewport(std::string_view name) {
  if (name == "nso-gba") {
    return nso_gba_viewport();
  }
  if (name == "native") {
    return native_switch_viewport();
  }
  return std::nullopt;
}

bool is_unit_box(const Box& box) {
  constexpr double kSlack = 1e-9;  // x + w of a box ending at 1, in floats
  return box.x >= 0 && box.y >= 0 && box.w > 0 && box.h > 0 &&
         box.x + box.w <= 1.0 + kSlack && box.y + box.h <= 1.0 + kSlack;
}

Box picture_box_to_frame(const Viewport& viewport, const Box& box) {
  const Box& picture = viewport.picture;
  return Box{picture.x + box.x * picture.w, picture.y + box.y * picture.h,
             box.w * picture.w, box.h * picture.h};
}

double frame_x_to_picture(const Viewport& viewport, double x) {
  return (x - viewport.picture.x) / viewport.picture.w;
}

double frame_y_to_picture(const Viewport& viewport, double y) {
  return (y - viewport.picture.y) / viewport.picture.h;
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

cv::Size template_size_in_frame(const Viewport& viewport, cv::Size game_size,
                                int width, int height) {
  const double x_scale = viewport.picture.w * width / viewport.game_width;
  const double y_scale = viewport.picture.h * height / viewport.game_height;
  const auto scaled = [](int size, double scale) {
    return std::max(1, static_cast<int>(std::lround(size * scale)));
  };
  return cv::Size(scaled(game_size.width, x_scale),
                  scaled(game_size.height, y_scale));
}

std::optional<Box> parse_box(std::string_view text) {
  const std::string copy(text);
  std::array<double, 4> values{};
  const char* cursor = copy.c_str();
  for (std::size_t i = 0; i < values.size(); i++) {
    char* next = nullptr;
    values[i] = std::strtod(cursor, &next);
    const char expected = i + 1 == values.size() ? '\0' : ',';
    if (next == cursor || *next != expected) {
      return std::nullopt;
    }
    cursor = next + 1;
  }
  const Box box{values[0], values[1], values[2], values[3]};
  if (!is_unit_box(box)) {
    return std::nullopt;
  }
  return box;
}

}  // namespace gamepilot
