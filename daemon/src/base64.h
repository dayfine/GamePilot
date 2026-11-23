// Base64 (RFC 4648, standard alphabet, padded) for template uploads.

#pragma once

#include <optional>
#include <string>
#include <string_view>

namespace gamepilot {

// The bytes `text` encodes; nullopt if it is not padded standard base64.
std::optional<std::string> decode_base64(std::string_view text);

}  // namespace gamepilot
