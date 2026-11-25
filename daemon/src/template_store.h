// Templates the client uploaded, decoded and keyed by the SHA-256 of their PNG
// bytes. They live until the client disconnects.

#pragma once

#include <map>
#include <opencv2/core.hpp>
#include <optional>
#include <string>
#include <string_view>

namespace gamepilot {

class TemplateStore {
 public:
  // Decodes a PNG as 8-bit BGR (alpha dropped), and again as 8-bit BGRA (an
  // image without alpha opaque), and keeps both. Returns its hash
  // (lowercase hex SHA-256 of the bytes), or nullopt if it does not decode.
  // Adding the same bytes again keeps one copy and returns the same hash.
  std::optional<std::string> add_png(std::string_view png);

  // The template with this hash, BGR, or nullptr.
  const cv::Mat* find(const std::string& hash) const;

  // The template with this hash, BGRA (core.find@1 reads its alpha), or
  // nullptr.
  const cv::Mat* find_with_alpha(const std::string& hash) const;

  void clear() { templates_.clear(); }

 private:
  struct Decoded {
    cv::Mat bgr;
    cv::Mat bgra;
  };
  std::map<std::string, Decoded> templates_;
};

}  // namespace gamepilot
