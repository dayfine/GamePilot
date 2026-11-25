// The scripts and styles a watch page loads: each <script src="NAME"> and
// <link rel="stylesheet" href="NAME">, for the tests that check every one is
// compiled in and served beside the page.

#pragma once

#include <string>
#include <string_view>
#include <vector>

namespace gamepilot::test {

inline std::vector<std::string> page_assets(std::string_view page) {
  std::vector<std::string> names;
  for (const std::string_view open :
       {std::string_view("<script src=\""),
        std::string_view("<link rel=\"stylesheet\" href=\"")}) {
    for (std::size_t at = page.find(open); at != std::string_view::npos;
         at = page.find(open, at + 1)) {
      const std::size_t start = at + open.size();
      names.emplace_back(page.substr(start, page.find('"', start) - start));
    }
  }
  return names;
}

// The Content-Type a script or a style is served with.
inline std::string_view asset_type(std::string_view name) {
  return name.ends_with(".css") ? "text/css; charset=utf-8"
                                : "text/javascript; charset=utf-8";
}

}  // namespace gamepilot::test
