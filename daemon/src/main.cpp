// gamepilot_daemon: serves the v1 wire protocol (contracts/v1) over one
// backend.
//
//   gamepilot_daemon --backend mgba --mgba-port 47810 [--port 47900] [--log f]
//   [--fast]
//   gamepilot_daemon --backend switch (--replay VIDEO | --capture DEVICE)
//   [--viewport x,y,w,h] [--port 47900] [--log f]
//
// Either takes [--watch-port 47901] [--listen ADDR] for the watch page
// (watch_server.h): on 127.0.0.1 unless --listen opens it to the network.
//
// The switch backend's inputs go to FakeSwitch's board for now: the real
// controller board needs its session handshake first (switch_controller.h).

#include <atomic>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <exception>
#include <memory>
#include <string>
#include <string_view>

#include "fake_switch.h"
#include "mgba_backend.h"
#include "net.h"
#include "server.h"
#include "switch_backend.h"

namespace {

std::atomic<bool> g_stop{false};

extern "C" void on_signal(int) { g_stop.store(true); }

int usage() {
  std::fputs(
      "usage: gamepilot_daemon --backend mgba --mgba-port N [--port 47900] "
      "[--log FILE] [--fast]\n"
      "       gamepilot_daemon --backend switch (--replay VIDEO | --capture "
      "DEVICE) [--viewport x,y,w,h] [--port 47900] [--log FILE]\n"
      "       either with [--watch-port 47901] [--listen 127.0.0.1] for the "
      "watch page\n",
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

struct Flags {
  std::string backend;
  std::uint16_t mgba_port = 0;
  std::string replay;
  std::string capture;
  gamepilot::SwitchOptions switch_options;
  gamepilot::ServerOptions server;
};

bool parse_flags(int argc, char** argv, Flags& flags) {
  for (int i = 1; i < argc; i++) {
    const std::string_view arg = argv[i];
    const bool has_value = i + 1 < argc;
    if (arg == "--backend" && has_value) {
      flags.backend = argv[++i];
    } else if (arg == "--mgba-port" && has_value) {
      if (!parse_port(argv[++i], flags.mgba_port)) {
        return false;
      }
    } else if (arg == "--replay" && has_value) {
      flags.replay = argv[++i];
    } else if (arg == "--capture" && has_value) {
      flags.capture = argv[++i];
    } else if (arg == "--viewport" && has_value) {
      const auto box = gamepilot::parse_box(argv[++i]);
      if (!box) {
        return false;
      }
      flags.switch_options.viewport.picture = *box;
    } else if (arg == "--port" && has_value) {
      if (!parse_port(argv[++i], flags.server.port)) {
        return false;
      }
    } else if (arg == "--log" && has_value) {
      flags.server.log_path = argv[++i];
    } else if (arg == "--watch-port" && has_value) {
      auto& watch = flags.server.watch.emplace(
          flags.server.watch.value_or(gamepilot::WatchOptions{}));
      if (!parse_port(argv[++i], watch.port)) {
        return false;
      }
    } else if (arg == "--listen" && has_value) {
      auto& watch = flags.server.watch.emplace(
          flags.server.watch.value_or(gamepilot::WatchOptions{}));
      watch.listen = argv[++i];
    } else if (arg == "--fast") {
      flags.server.fast = true;
    } else {
      return false;
    }
  }
  if (flags.backend == "mgba") {
    return flags.mgba_port != 0;
  }
  if (flags.backend == "switch") {
    return flags.replay.empty() != flags.capture.empty();
  }
  return false;
}

// Serves until a signal; returns the exit status.
int serve(gamepilot::Backend& backend,
          const gamepilot::ServerOptions& options) {
  gamepilot::Server server(backend, options);
  std::fprintf(stderr, "daemon: listening on 127.0.0.1:%u%s\n",
               static_cast<unsigned>(options.port),
               options.fast ? " (fast)" : "");
  if (options.watch) {
    std::fprintf(stderr, "daemon: watch page on http://%s:%u/\n",
                 options.watch->listen.c_str(),
                 static_cast<unsigned>(server.watch_port()));
    if (options.watch->listen != "127.0.0.1") {
      std::fprintf(stderr,
                   "daemon: the watch page is open to the network (--listen "
                   "%s): anyone who reaches it can watch and press Stop\n",
                   options.watch->listen.c_str());
    }
  }
  try {
    server.run(g_stop);
    return 0;
  } catch (const std::exception& error) {
    std::fprintf(stderr, "daemon: %s\n", error.what());
    return 1;
  }
}

int run_mgba(const Flags& flags) {
  gamepilot::MgbaBackend backend(flags.mgba_port);
  std::fprintf(
      stderr, "daemon: mgba bridge on %u, game %s, held at frame %lld\n",
      static_cast<unsigned>(flags.mgba_port), backend.info().game_code.c_str(),
      static_cast<long long>(backend.seq()));
  const int status = serve(backend, flags.server);
  std::fprintf(stderr,
               "daemon: stopped at frame %lld; %lld KEYS applied late\n",
               static_cast<long long>(backend.seq()),
               static_cast<long long>(backend.late_keys()));
  return status;
}

int run_switch(const Flags& flags) {
  const gamepilot::Clock clock;
  constexpr std::uint32_t kSession = 0x47500001;
  gamepilot::FakeSwitch board(clock, kSession);
  gamepilot::Pabb2Controller controller(board, kSession);
  const auto attached = board.attach(controller);
  controller.reset();
  std::unique_ptr<gamepilot::FrameSource> source =
      flags.replay.empty()
          ? gamepilot::open_capture_card({.device = flags.capture})
          : gamepilot::open_video_replay(flags.replay, clock);
  gamepilot::SwitchBackend backend(std::move(source), controller, clock,
                                   flags.switch_options);
  std::fprintf(
      stderr,
      "daemon: switch, %s %s, %dx%d at %.2f fps; inputs go to a fake "
      "controller board\n",
      flags.replay.empty() ? "capture" : "replay",
      flags.replay.empty() ? flags.capture.c_str() : flags.replay.c_str(),
      backend.info().width, backend.info().height, backend.info().frame_rate);
  return serve(backend, flags.server);
}

}  // namespace

int main(int argc, char** argv) {
  Flags flags;
  if (!parse_flags(argc, argv, flags)) {
    return usage();
  }

  std::signal(SIGINT, on_signal);
  std::signal(SIGTERM, on_signal);
#ifdef SIGPIPE
  std::signal(SIGPIPE, SIG_IGN);
#endif

  try {
    gamepilot::init_sockets();
    return flags.backend == "mgba" ? run_mgba(flags) : run_switch(flags);
  } catch (const std::exception& error) {
    std::fprintf(stderr, "daemon: %s\n", error.what());
    return 1;
  }
}
