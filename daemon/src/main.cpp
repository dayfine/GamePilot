// gamepilot_daemon: serves the v1 wire protocol (contracts/v1) over one
// backend.
//
//   gamepilot_daemon --backend mgba --mgba-port 47810 [--port 47900] [--log f]
//   [--fast]

#include <atomic>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <exception>
#include <memory>
#include <string>
#include <string_view>

#include "mgba_backend.h"
#include "net.h"
#include "server.h"

namespace {

std::atomic<bool> g_stop{false};

extern "C" void on_signal(int) { g_stop.store(true); }

int usage() {
  std::fputs(
      "usage: gamepilot_daemon --backend mgba --mgba-port N [--port 47900] "
      "[--log FILE] "
      "[--fast]\n",
      stderr);
  return 2;
}

bool parse_port(const char* text, std::uint16_t& port) {
  char* end = nullptr;
  const long value = std::strtol(text, &end, 10);
  if (end == text || *end != '\0' || value <= 0 || value > 65535) {
    return false;
  }
  port = static_cast<std::uint16_t>(value);
  return true;
}

}  // namespace

int main(int argc, char** argv) {
  std::string backend_kind;
  std::uint16_t mgba_port = 0;
  gamepilot::ServerOptions options;
  for (int i = 1; i < argc; i++) {
    const std::string_view arg = argv[i];
    const bool has_value = i + 1 < argc;
    if (arg == "--backend" && has_value) {
      backend_kind = argv[++i];
    } else if (arg == "--mgba-port" && has_value) {
      if (!parse_port(argv[++i], mgba_port)) {
        return usage();
      }
    } else if (arg == "--port" && has_value) {
      if (!parse_port(argv[++i], options.port)) {
        return usage();
      }
    } else if (arg == "--log" && has_value) {
      options.log_path = argv[++i];
    } else if (arg == "--fast") {
      options.fast = true;
    } else {
      return usage();
    }
  }
  if (backend_kind != "mgba" || mgba_port == 0) {
    return usage();
  }

  std::signal(SIGINT, on_signal);
  std::signal(SIGTERM, on_signal);
#ifdef SIGPIPE
  std::signal(SIGPIPE, SIG_IGN);
#endif

  try {
    gamepilot::init_sockets();
    gamepilot::MgbaBackend backend(mgba_port);
    std::fprintf(
        stderr, "daemon: mgba bridge on %u, game %s, held at frame %lld\n",
        static_cast<unsigned>(mgba_port), backend.info().game_code.c_str(),
        static_cast<long long>(backend.seq()));
    gamepilot::Server server(backend, options);
    std::fprintf(stderr, "daemon: listening on 127.0.0.1:%u%s\n",
                 static_cast<unsigned>(options.port),
                 options.fast ? " (fast)" : "");
    int status = 0;
    try {
      server.run(g_stop);
    } catch (const std::exception& error) {
      std::fprintf(stderr, "daemon: %s\n", error.what());
      status = 1;
    }
    std::fprintf(stderr,
                 "daemon: stopped at frame %lld; %lld KEYS applied late\n",
                 static_cast<long long>(backend.seq()),
                 static_cast<long long>(backend.late_keys()));
    return status;
  } catch (const std::exception& error) {
    std::fprintf(stderr, "daemon: %s\n", error.what());
    return 1;
  }
}
