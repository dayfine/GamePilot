#include "template_store.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>
#include <vector>

#include "Common/Cpp/Cryptography/SHA256.h"

namespace gamepilot {

namespace {

// The PNG as 8-bit BGRA: 16-bit channels scaled down, gray and colour without
// alpha made opaque.
cv::Mat decode_bgra(const std::vector<unsigned char>& bytes) {
  cv::Mat image = cv::imdecode(bytes, cv::IMREAD_UNCHANGED);
  if (image.empty()) {
    return image;
  }
  if (image.depth() == CV_16U) {
    constexpr double kSixteenToEight = 1.0 / 257;
    image.convertTo(image, CV_8U, kSixteenToEight);
  }
  cv::Mat bgra;
  switch (image.channels()) {
    case 1:
      cv::cvtColor(image, bgra, cv::COLOR_GRAY2BGRA);
      break;
    case 3:
      cv::cvtColor(image, bgra, cv::COLOR_BGR2BGRA);
      break;
    default:
      bgra = image;
      break;
  }
  return bgra;
}

}  // namespace

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
  cv::Mat with_alpha = decode_bgra(bytes);
  if (image.empty() || with_alpha.empty()) {
    return std::nullopt;
  }
  templates_.emplace(hash, Decoded{std::move(image), std::move(with_alpha)});
  return hash;
}

const cv::Mat* TemplateStore::find(const std::string& hash) const {
  const auto it = templates_.find(hash);
  return it == templates_.end() ? nullptr : &it->second.bgr;
}

const cv::Mat* TemplateStore::find_with_alpha(const std::string& hash) const {
  const auto it = templates_.find(hash);
  return it == templates_.end() ? nullptr : &it->second.bgra;
}

}  // namespace gamepilot
