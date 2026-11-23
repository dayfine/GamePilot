#include "sent_results.h"

#include "rpc.h"

namespace gamepilot {

pa::JsonObject SentResults::take_changed(
    const std::vector<std::pair<std::string, ProbeResult>>& results) {
  pa::JsonObject changed;
  for (const auto& [id, result] : results) {
    pa::JsonObject json = probe_result_json(result);
    std::string line = json.dump(-1);
    auto [it, inserted] = sent_.try_emplace(id, line);
    if (!inserted && it->second == line) {
      continue;
    }
    it->second = std::move(line);
    changed[id] = std::move(json);
  }
  return changed;
}

void SentResults::forget(const std::string& id) { sent_.erase(id); }

void SentResults::forget_all() { sent_.clear(); }

}  // namespace gamepilot
