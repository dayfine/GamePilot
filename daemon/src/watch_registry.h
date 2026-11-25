// The registry of live watch pages: one small JSON file per daemon that serves
// a page, `<dir>/<pid>.json` (the runner's dir is `$GAMEPILOT_RUNS/.watch`).
// The daemon writes its entry once its page listens and removes it on exit;
// a daemon that died without removing it leaves a stale entry, which readers
// skip because its pid is gone. The hub (watch_hub.h) and `gamepilot runs`
// list the live ones.

#pragma once

#include <cstdint>
#include <functional>
#include <optional>
#include <string>
#include <vector>

namespace gamepilot {

struct RegistryEntry {
  std::int64_t pid = 0;
  std::uint16_t port = 0;       // the watch page's
  std::string listen;           // the address it is bound to
  std::string backend;          // "mgba", "switch"
  std::string run_folder;       // the run's folder; empty when none was given
  std::string checkpoint;       // the checkpoint it runs; empty when none
  std::int64_t started_ms = 0;  // when the daemon started, Unix ms
  // A view-only source's (view_backend.h): its hub name (/runs/NAME/, else
  // the run folder's name) and what it shows ("pacc-window"); both empty for
  // our own runs. Older readers ignore them.
  std::string name = {};
  std::string source = {};
};

std::string registry_entry_json(const RegistryEntry& entry);
// Nothing for a file that is not an entry.
std::optional<RegistryEntry> parse_registry_entry(const std::string& json);

// Whether a process with this pid is running.
bool process_alive(std::int64_t pid);

// The current process's pid.
std::int64_t own_pid();
// Wall-clock time, Unix ms (an entry's `started_ms`).
std::int64_t unix_now_ms();

// The entries in `dir` whose process is alive (`alive`), in pid order;
// none when the folder does not exist.
std::vector<RegistryEntry> live_entries(
    const std::string& dir,
    const std::function<bool(std::int64_t)>& alive = process_alive);

// This daemon's entry, written on construction (the folder is created when
// missing) and removed on destruction. Throws std::runtime_error when it
// cannot write it.
class RegistryFile {
 public:
  RegistryFile(const std::string& dir, const RegistryEntry& entry);
  ~RegistryFile();
  RegistryFile(const RegistryFile&) = delete;
  RegistryFile& operator=(const RegistryFile&) = delete;

  const std::string& path() const { return path_; }

 private:
  std::string path_;
};

}  // namespace gamepilot
