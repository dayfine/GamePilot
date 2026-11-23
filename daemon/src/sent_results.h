// The probe results the client already holds. A frame notification carries a
// result only when it differs from the one last sent for that probe id
// (contract v1.4); forgetting a probe makes the next frame send it again.

#pragma once

#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "Common/Cpp/Json/JsonObject.h"
#include "probes.h"

namespace gamepilot {

namespace pa = PokemonAutomation;

class SentResults {
 public:
  // A frame's `probes` object: the results whose JSON differs from the last
  // one sent for their id (all of them for ids not sent yet). Remembers them
  // as sent.
  pa::JsonObject take_changed(
      const std::vector<std::pair<std::string, ProbeResult>>& results);

  void forget(const std::string& id);
  void forget_all();

 private:
  // Probe id -> its last sent result as compact JSON.
  std::unordered_map<std::string, std::string> sent_;
};

}  // namespace gamepilot
