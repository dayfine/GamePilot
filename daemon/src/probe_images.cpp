// probe_images: runs the daemon's probes on PNG images, offline (no backend,
// no socket), and prints one JSON line per image:
// {"image": path, "probes": {id: result}}, the `probes` object of a `frame`
// notification.
//
//   probe_images --spec probes.json [--viewport x,y,w,h|nso-gba|native]
//                [--game-size WxH] image.png [image.png ...]
//
// The spec file holds the `subscribe` params ({"probes": [...]}); a
// core.template_match@1 probe's `template` is a PNG path, relative to the spec
// file's folder, that the tool uploads to its own template store.
// --viewport is where the game picture sits in every image, normalized
// (default the whole image, as on mGBA; a Switch capture has side bars, and
// nso-gba is the Switch's GBA app as the daemon's switch backend sees it;
// native is a full-screen Switch game, the whole image in 1920x1080 game
// pixels), and --game-size the picture's native size in game pixels (default
// 240x160, the GBA), which templates are given in. A viewport name sets the
// game size too, so a --game-size goes after it.

#include <cstdio>
#include <cstdlib>
#include <opencv2/imgcodecs.hpp>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "Common/Cpp/Exceptions.h"
#include "Common/Cpp/Filesystem/FileIO.h"
#include "Common/Cpp/Filesystem/FilePath.h"
#include "Common/Cpp/Json/JsonValue.h"
#include "probe_evaluation.h"
#include "rpc.h"
#include "template_store.h"

namespace {

namespace gp = gamepilot;
namespace pa = PokemonAutomation;

int usage() {
  std::fputs(
      "usage: probe_images --spec FILE [--viewport x,y,w,h|nso-gba|native] "
      "[--game-size WxH] IMAGE.png [IMAGE.png ...]\n",
      stderr);
  return 2;
}

// "WxH" with both positive, into the viewport's game size.
bool parse_game_size(const char* text, gp::Viewport& viewport) {
  char* end = nullptr;
  const long width = std::strtol(text, &end, 10);
  if (end == text || *end != 'x') {
    return false;
  }
  const char* height_text = end + 1;
  const long height = std::strtol(height_text, &end, 10);
  if (end == height_text || *end != '\0' || width <= 0 || height <= 0) {
    return false;
  }
  viewport.game_width = static_cast<int>(width);
  viewport.game_height = static_cast<int>(height);
  return true;
}

// Thrown for a bad spec or image; main prints it and exits 1.
struct InputError {
  std::string message;
};

// The probes of the spec file, with each template PNG uploaded to `templates`
// and its path replaced by the hash.
std::vector<gp::ProbeSpec> load_probes(const std::string& spec_path,
                                       gp::TemplateStore& templates) {
  const pa::JsonValue spec = pa::load_json_file(spec_path);
  const pa::JsonObject* params = spec.to_object();
  if (params == nullptr) {
    throw InputError{spec_path + ": not a JSON object"};
  }
  std::vector<gp::ProbeSpec> probes = gp::decode_subscribe(*params).probes;
  const pa::Filesystem::Path folder =
      pa::Filesystem::Path(spec_path).parent_path();
  for (gp::ProbeSpec& probe : probes) {
    if (probe.kind != gp::kTemplateMatchKind) {
      continue;
    }
    const std::string png_path =
        (folder / pa::Filesystem::Path(probe.template_hash)).string();
    const std::optional<std::string> hash =
        templates.add_png(pa::file_to_string(png_path));
    if (!hash) {
      throw InputError{png_path + ": not a PNG"};
    }
    probe.template_hash = *hash;
  }
  return probes;
}

cv::Mat load_image(const std::string& path) {
  const std::string bytes = pa::file_to_string(path);
  const std::vector<unsigned char> data(bytes.begin(), bytes.end());
  cv::Mat image = cv::imdecode(data, cv::IMREAD_COLOR);
  if (image.empty()) {
    throw InputError{path + ": not an image"};
  }
  return image;
}

pa::JsonValue image_line(const std::string& path,
                         const std::vector<gp::ProbeSpec>& probes,
                         const gp::TemplateStore& templates,
                         const gp::Viewport& viewport) {
  const cv::Mat image = load_image(path);
  std::vector<std::pair<std::string, gp::ProbeResult>> results;
  for (const gp::ProbeSpec& probe : probes) {
    gp::FrameProbe mapped;
    try {
      mapped =
          gp::map_probe(probe, templates, viewport, image.cols, image.rows);
    } catch (const gp::RpcError& error) {
      throw InputError{path + ": " + error.what()};
    }
    results.emplace_back(probe.id, gp::evaluate_probe(mapped, image));
  }
  pa::JsonObject line;
  line["image"] = path;
  line["probes"] = gp::probe_results_json(results);
  return line;
}

}  // namespace

int main(int argc, char** argv) {
  std::string spec_path;
  std::vector<std::string> image_paths;
  constexpr int kGbaWidth = 240;
  constexpr int kGbaHeight = 160;
  gp::Viewport viewport{gp::Box{0, 0, 1, 1}, kGbaWidth, kGbaHeight};
  for (int i = 1; i < argc; i++) {
    const std::string_view arg = argv[i];
    const bool has_value = i + 1 < argc;
    if (arg == "--spec" && has_value) {
      spec_path = argv[++i];
    } else if (arg == "--viewport" && has_value) {
      const std::optional<gp::Viewport> parsed =
          gp::parse_viewport(argv[++i], viewport);
      if (!parsed) {
        return usage();
      }
      viewport = *parsed;
    } else if (arg == "--game-size" && has_value) {
      if (!parse_game_size(argv[++i], viewport)) {
        return usage();
      }
    } else if (arg.starts_with("--")) {
      return usage();
    } else {
      image_paths.emplace_back(arg);
    }
  }
  if (spec_path.empty() || image_paths.empty()) {
    return usage();
  }

  try {
    gp::TemplateStore templates;
    const std::vector<gp::ProbeSpec> probes = load_probes(spec_path, templates);
    for (const std::string& path : image_paths) {
      const std::string line =
          gp::to_line(image_line(path, probes, templates, viewport)) + "\n";
      std::fputs(line.c_str(), stdout);
    }
    return 0;
  } catch (const InputError& error) {
    std::fprintf(stderr, "probe_images: %s\n", error.message.c_str());
  } catch (const gp::RpcError& error) {
    std::fprintf(stderr, "probe_images: %s: %s\n", spec_path.c_str(),
                 error.what());
  } catch (const pa::Exception& error) {
    std::fprintf(stderr, "probe_images: %s\n", error.message().c_str());
  }
  return 1;
}
