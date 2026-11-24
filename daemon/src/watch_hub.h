// The hub: one page at a fixed port (47901) that lists the live runs from the
// watch registry (watch_registry.h) and links to each run's own page. It is
// the daemon started with `--hub`, no backend, serving only HTTP with the same
// pieces as the watch page (http.h, net.h):
//
//   GET /            the page (watch/hub.html, compiled in): the runs, each
//                    with its checkpoint, mode and trial (from the run's
//                    /summary.json), elapsed time and state
//   GET /runs.json   the live registry entries
//
// The runner starts it when nothing listens on its port, so one runs per
// machine; a second one finds the port taken and exits.

#pragma once

#include <atomic>
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

#include "net.h"
#include "watch_registry.h"

namespace gamepilot {

struct HubOptions {
  std::string listen = "127.0.0.1";
  std::uint16_t port = 47901;
  std::string registry;  // the registry folder
};

// The entries as /runs.json gives them: the run folder's name only, so its
// path stays on this machine.
std::string hub_runs_json(const std::vector<RegistryEntry>& entries);

class WatchHub {
 public:
  // Throws std::runtime_error when it cannot listen.
  explicit WatchHub(HubOptions options);

  std::uint16_t port() const { return local_port(listener_); }

  // Serves until `stop` turns true.
  void run(const std::atomic<bool>& stop);

 private:
  struct Connection {
    Socket socket;
    std::string request;
  };

  void serve(const std::vector<bool>& readable);
  void read(Connection& connection);

  HubOptions options_;
  Socket listener_;
  std::vector<Connection> connections_;
};

// The page, compiled in from watch/hub.html (hub_page.cpp is generated).
std::string_view hub_page();

}  // namespace gamepilot
