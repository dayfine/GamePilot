// The watch registry and the hub: an entry is written while its daemon lives
// and removed after; readers skip stale entries (dead pid), other files and
// a missing folder; the hub's list keeps run folder paths off the network;
// a hub asked for port 0 gets a free one.

#include "watch_registry.h"

#include <string>

#include "Common/Cpp/Filesystem/FileIO.h"
#include "Common/Cpp/Filesystem/Filesystem.h"
#include "check.h"
#include "net.h"
#include "watch_hub.h"

using namespace gamepilot;
namespace pa = PokemonAutomation;
namespace fs = pa::Filesystem;

namespace {

const std::string kDir =
    std::string(GAMEPILOT_TEST_OUTPUT_DIR) + "/watch_registry";

RegistryEntry entry(std::int64_t pid, const std::string& checkpoint) {
  return RegistryEntry{pid,
                       47950,
                       "127.0.0.1",
                       "mgba",
                       "/runs/2026-11-23-" + checkpoint + "-testing-1",
                       checkpoint,
                       1795435200000};
}

void check_entry_json() {
  const RegistryEntry written = entry(4242, "mg-02");
  const auto read = parse_registry_entry(registry_entry_json(written));
  CHECK(read && read->pid == 4242 && read->port == 47950 &&
        read->listen == "127.0.0.1" && read->backend == "mgba" &&
        read->run_folder == written.run_folder && read->checkpoint == "mg-02" &&
        read->started_ms == 1795435200000);
  for (const std::string& bad :
       {"", "not json", "[1]", "{\"port\":47950}", "{\"pid\":1}",
        "{\"pid\":1,\"port\":0}", "{\"pid\":0,\"port\":47950}",
        "{\"pid\":1,\"port\":70000}"}) {
    CHECK(!parse_registry_entry(bad));
  }
}

void check_entry_file() {
  fs::remove_all(kDir);
  CHECK(live_entries(kDir).empty());  // no folder yet
  std::string path;
  {
    const RegistryFile file(kDir, entry(own_pid(), "mg-01"));
    path = file.path();
    CHECK(fs::exists(path));
    // One JSON line as it is: no BOM, no CR (other readers parse it too).
    CHECK(fs::file_size(path) ==
          registry_entry_json(entry(own_pid(), "mg-01")).size() + 1);
    CHECK(path.ends_with("/" + std::to_string(own_pid()) + ".json"));
    const auto live = live_entries(kDir);
    CHECK(live.size() == 1 && live[0].pid == own_pid() &&
          live[0].checkpoint == "mg-01");
  }
  CHECK(!fs::exists(path));
  CHECK(live_entries(kDir).empty());
}

void check_stale_entries() {
  fs::remove_all(kDir);
  fs::create_directories(kDir);
  constexpr std::int64_t kDead = 999999001;  // no such process
  CHECK(process_alive(own_pid()));
  CHECK(!process_alive(kDead));
  CHECK(!process_alive(0));
  pa::string_to_file(kDir + "/" + std::to_string(kDead) + ".json",
                     registry_entry_json(entry(kDead, "mg-03")));
  pa::string_to_file(kDir + "/junk.json", "{");
  pa::string_to_file(kDir + "/notes.txt",
                     registry_entry_json(entry(own_pid(), "mg-09")));
  pa::string_to_file(kDir + "/1.json", registry_entry_json(entry(7, "b")));
  pa::string_to_file(kDir + "/2.json", registry_entry_json(entry(5, "a")));
  const RegistryFile own(kDir, entry(own_pid(), "mg-04"));

  const auto live = live_entries(kDir);
  CHECK(live.size() == 1 && live[0].checkpoint == "mg-04");

  // In pid order; `alive` decides what is stale.
  const auto all = live_entries(kDir, [](std::int64_t) { return true; });
  CHECK(all.size() == 4 && all[0].pid == 5 && all[1].pid == 7);
}

void check_hub() {
  const std::string json = hub_runs_json({entry(12, "mg-05")});
  CHECK(json.find("\"run\":\"2026-11-23-mg-05-testing-1\"") !=
        std::string::npos);
  CHECK(json.find("/runs/") == std::string::npos);
  CHECK(json.find("\"port\":47950") != std::string::npos);
  CHECK(hub_runs_json({}) == "[]");

  const WatchHub hub(HubOptions{"127.0.0.1", 0, kDir});
  CHECK(hub.port() != 0);
  bool taken = false;
  try {
    const WatchHub second(HubOptions{"127.0.0.1", hub.port(), kDir});
  } catch (const std::runtime_error&) {
    taken = true;
  }
  CHECK(taken);
}

}  // namespace

int main() {
  init_sockets();
  check_entry_json();
  check_entry_file();
  check_stale_entries();
  check_hub();
  fs::remove_all(kDir);
  return TEST_RESULT();
}
