#include "template_store.h"

#include <opencv2/imgcodecs.hpp>
#include <vector>

#include "Common/Cpp/Cryptography/SHA256.h"

namespace gamepilot {

std::optional<std::string> TemplateStore::add_png(std::string_view png) {
  PokemonAutomation::SHA256 sha;
  sha.push(png.data(), png.size());
  sha.finish();
  std::string hash = sha.get_hash_hex();
  if (templates_.contains(hash)) {
    return hash;
  }
  const std::vector<unsigned char> bytes(png.begin(), png.end());
  cv::Mat image = cv::imdecode(bytes, cv::IMREAD_COLOR);
  if (image.empty()) {
    return std::nullopt;
  }
  templates_.emplace(hash, std::move(image));
  return hash;
}

const cv::Mat* TemplateStore::find(const std::string& hash) const {
  const auto it = templates_.find(hash);
  return it == templates_.end() ? nullptr : &it->second;
}

}  // namespace gamepilot
