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
  // Decodes a PNG as 8-bit BGR (alpha dropped) and keeps it. Returns its hash
  // (lowercase hex SHA-256 of the bytes), or nullopt if it does not decode.
  // Adding the same bytes again keeps one copy and returns the same hash.
  std::optional<std::string> add_png(std::string_view png);

  // The template with this hash, or nullptr.
  const cv::Mat* find(const std::string& hash) const;

  void clear() { templates_.clear(); }

 private:
  std::map<std::string, cv::Mat> templates_;
};

}  // namespace gamepilot
