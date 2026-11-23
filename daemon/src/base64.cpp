#include "base64.h"

#include <array>
#include <cstdint>

namespace gamepilot {

namespace {

constexpr std::string_view kAlphabet =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
constexpr int kNotInAlphabet = -1;

std::array<int, 256> make_sextet_table() {
  std::array<int, 256> table{};
  table.fill(kNotInAlphabet);
  for (std::size_t i = 0; i < kAlphabet.size(); i++) {
    table[static_cast<unsigned char>(kAlphabet[i])] = static_cast<int>(i);
  }
  return table;
}

}  // namespace

std::optional<std::string> decode_base64(std::string_view text) {
  static const std::array<int, 256> sextets = make_sextet_table();
  if (text.size() % 4 != 0) {
    return std::nullopt;
  }
  std::string bytes;
  bytes.reserve(text.size() / 4 * 3);
  for (std::size_t group = 0; group < text.size(); group += 4) {
    const std::string_view quad = text.substr(group, 4);
    // Only the last group may end in '=' or "==".
    std::size_t padding = 0;
    if (group + 4 == text.size()) {
      padding = quad[3] != '=' ? 0 : (quad[2] != '=' ? 1 : 2);
    }
    std::uint32_t bits = 0;
    for (std::size_t i = 0; i < 4; i++) {
      int value = 0;
      if (i < 4 - padding) {
        value = sextets[static_cast<unsigned char>(quad[i])];
        if (value == kNotInAlphabet) {
          return std::nullopt;
        }
      }
      bits = (bits << 6) | static_cast<std::uint32_t>(value);
    }
    for (std::size_t i = 0; i < 3 - padding; i++) {
      bytes.push_back(static_cast<char>((bits >> (16 - 8 * i)) & 0xff));
    }
  }
  return bytes;
}

}  // namespace gamepilot
