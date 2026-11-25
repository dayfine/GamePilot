// gamepilot_daemon: serves the v1 wire protocol (protocol/v1) over one
// backend.
//
//   gamepilot_daemon --backend mgba --mgba-port 47810 [--port 47900] [--log f]
//   [--fast | --speed S]
//
// --speed S steps mGBA S times its frame rate (0.25 to 16; the emulator must
// not throttle itself: audio and video sync off). Presses, waits and the t_ms
// of frames and batch_done stay in game time (protocol/v1/README.md, Clock
// and frames), so a program runs the same at any speed.
//   gamepilot_daemon --backend switch (--replay VIDEO | --capture DEVICE)
//   [--serial PORT] [--viewport nso-gba|native|x,y,w,h] [--port 47900]
//   [--log f]
//   gamepilot_daemon --backend switch --serial PORT --board-check
//   gamepilot_daemon --backend switch --capture DEVICE --capture-check PNG
//
// --viewport says where the game picture sits in the frame (viewport.h):
// nso-gba, the default, is the GBA picture in the Switch's GBA app (FRLG);
// native is a full-screen Switch game, the whole frame in 1920x1080 game
// pixels; x,y,w,h moves the picture box and keeps the game size.
//
// Either takes [--watch-port 47901] [--listen ADDR] [--watch-token T] for the
// watch page (watch_server.h): on 127.0.0.1 unless --listen opens it to the
// network; port 0 (here and for --port) picks a free one, which the daemon
// prints. With [--registry DIR] [--checkpoint ID] [--run-folder DIR] the page
// is listed in the watch registry (watch_registry.h) while it is up.
// [--record | --no-record] records the run's frames into DIR/frames (on by
// default for the switch backend with a run folder, off for mgba);
// [--keepawake SECONDS] [--keepawake-key B] presses that key after SECONDS
// with no input, never during a client's batch (keep_awake.h; default 180 on
// the switch backend, 0 = off, off for mgba).
// [--stream-fps 30] [--stream-width 1280] set the page's live frame
// (frame_stream.h): at most that many frames a second, a capture card's frame
// scaled to that width unless the viewer asks for another (`/stream?w=`).
//
//   gamepilot_daemon --backend view (--window-pid PID | --window-app PATH)
//   [--window-title T] [--crop x,y,w,h | --crop auto] [--stale-s 10]
//   [--name NAME] [--source LABEL] [--tail-log FILE]
//   gamepilot_daemon --backend view --replay VIDEO ...
//
// is view-only (view_backend.h): it shows another program's picture (an
// app's window through ScreenCaptureKit on macOS, window_capture.h; or a
// recorded video) on the watch page, cropped to the video, with no input, no
// lease and no keep-awake: input methods answer an error. --name lists it in
// the hub as /runs/NAME/ and --source says what it is (default "window");
// the hub puts it under Watching and /live skips it. --tail-log follows
// another program's log (read only) into the page's log.
//
//   gamepilot_daemon --hub --registry DIR [--watch-port 47901] [--listen ADDR]
//
// serves the hub (watch_hub.h), the list of live runs and each run's page
// under /runs/NAME/ (recent finished ones from DIR/../RESULTS.tsv), in its own
// session so the terminal that started it can close; exits 0 at once when its port is
// taken (a hub already runs).
//
// The switch backend's inputs go to the controller board on --serial (its
// session started as the C++ app starts it, board_session.h, as a Pro
// Controller: the board must already run NS1 Wired Pro Controller, a mode the
// daemon never changes), else to FakeSwitch's board. --board-check only starts
// the session (checking the mode), prints what the board said and exits;
// --capture-check saves one captured frame and checks the game picture sits
// where the viewport says (switch_geometry.h). Without --serial, and
// with --replay in place of --capture, both check the fakes: a dry run
// (run/run_checkpoints_on_switch.sh --dry-run). Bring-up:
// docs/switch-bring-up.md.

#include <atomic>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <limits>
#include <exception>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <string_view>

#include "board_session.h"
#include "fake_switch.h"
#include "mgba_backend.h"
#include "net.h"
#include "run_history.h"
#include "server.h"
#include "switch_backend.h"
#include "switch_geometry.h"
#include "view_backend.h"
#include "watch_hub.h"
#include "window_capture.h"

#ifndef _WIN32
#include <unistd.h>
#endif

namespace {

std::atomic<bool> g_stop{false};

extern "C" void on_signal(int) { g_stop.store(true); }

int usage() {
  std::fputs(
      "usage: gamepilot_daemon --backend mgba --mgba-port N [--port 47900] "
      "[--log FILE] [--fast | --speed S]\n"
      "       gamepilot_daemon --backend switch (--replay VIDEO | --capture "
      "DEVICE) [--serial PORT]\n"
      "         [--viewport nso-gba|native|x,y,w,h] [--port 47900] "
      "[--log FILE]\n"
      "       gamepilot_daemon --backend switch [--serial PORT] --board-check\n"
      "       gamepilot_daemon --backend switch (--capture DEVICE | --replay "
      "VIDEO) --capture-check PNG\n"
      "       either with [--watch-port 47901] [--listen 127.0.0.1] "
      "[--watch-token T]\n"
      "         [--registry DIR] [--checkpoint ID] [--run-folder DIR] "
      "[--stream-fps 30]\n"
      "         [--stream-width 1280] for the watch page\n"
      "       either with [--record | --no-record] [--keepawake SECONDS] "
      "[--keepawake-key B]\n"
      "       gamepilot_daemon --backend view (--window-pid PID | "
      "--window-app PATH | --replay VIDEO) [--window-title T]\n"
      "         [--crop x,y,w,h | --crop auto] [--stale-s 10] [--name NAME] "
      "[--source LABEL] [--tail-log FILE]\n"
      "       gamepilot_daemon --hub --registry DIR [--watch-port 47901] "
      "[--listen 127.0.0.1]\n",
      stderr);
  return 2;
}

// A port; 0 asks for any free one.
bool parse_port(const char* text, std::uint16_t& port) {
  char* end = nullptr;
  const long value = std::strtol(text, &end, 10);
  if (end == text || *end != '\0' || value < 0 || value > 65535) {
    return false;
  }
  port = static_cast<std::uint16_t>(value);
  return true;
}

// A whole number in [low, high].
bool parse_in_range(const char* text, long low, long high, long& value) {
  char* end = nullptr;
  value = std::strtol(text, &end, 10);
  return end != text && *end == '\0' && value >= low && value <= high;
}

// A lockstep speed: a number from 0.25 to 16.
bool parse_speed(const char* text, double& speed) {
  constexpr double kMinSpeed = 0.25;
  constexpr double kMaxSpeed = 16;
  char* end = nullptr;
  const double value = std::strtod(text, &end);
  if (end == text || *end != '\0' || !(value >= kMinSpeed) ||
      !(value <= kMaxSpeed)) {
    return false;
  }
  speed = value;
  return true;
}

struct Flags {
  std::string backend;
  std::uint16_t mgba_port = 0;
  std::string replay;
  std::string capture;
  std::string serial;
  bool board_check = false;
  std::string capture_check;
  gamepilot::SwitchOptions switch_options;
  gamepilot::ServerOptions server;
  bool hub = false;
  std::optional<bool> record;           // default: by backend
  std::optional<double> keepawake_s;    // default: by backend
  gamepilot::WindowCaptureConfig window;
  gamepilot::ViewOptions view;
};

// Recording and keep-awake are on by default on the Switch only: mGBA's runs
// are short and its frames come back from save states.
constexpr double kSwitchKeepAwakeS = 180;
constexpr long kMaxKeepAwakeS = 24 * 3600;

void backend_defaults(Flags& flags) {
  const bool console = flags.backend == "switch";
  flags.server.record = flags.record.value_or(console);
  flags.server.keepawake.idle_ms =
      flags.keepawake_s.value_or(console ? kSwitchKeepAwakeS : 0) * 1000;
}

gamepilot::WatchOptions& watch_options(Flags& flags) {
  return flags.server.watch.emplace(
      flags.server.watch.value_or(gamepilot::WatchOptions{}));
}

// The view backend: one source (a window by pid or app, or a video), nothing
// that drives a console.
bool valid_view_flags(Flags& flags) {
  const int sources = (flags.window.pid != 0 ? 1 : 0) +
                      (flags.window.app_path.empty() ? 0 : 1) +
                      (flags.replay.empty() ? 0 : 1);
  if (flags.server.source.empty()) {
    flags.server.source = flags.replay.empty() ? "window" : "video";
  }
  return sources == 1 && flags.capture.empty() && flags.serial.empty() &&
         !flags.board_check && flags.capture_check.empty() &&
         flags.server.keepawake.idle_ms == 0;
}

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
    } else if (arg == "--serial" && has_value) {
      flags.serial = argv[++i];
    } else if (arg == "--board-check") {
      flags.board_check = true;
    } else if (arg == "--capture-check" && has_value) {
      flags.capture_check = argv[++i];
    } else if (arg == "--viewport" && has_value) {
      const std::optional<gamepilot::Viewport> viewport =
          gamepilot::parse_viewport(argv[++i], flags.switch_options.viewport);
      if (!viewport) {
        return false;
      }
      flags.switch_options.viewport = *viewport;
    } else if (arg == "--port" && has_value) {
      if (!parse_port(argv[++i], flags.server.port)) {
        return false;
      }
    } else if (arg == "--log" && has_value) {
      flags.server.log_path = argv[++i];
    } else if (arg == "--watch-port" && has_value) {
      if (!parse_port(argv[++i], watch_options(flags).port)) {
        return false;
      }
    } else if (arg == "--listen" && has_value) {
      watch_options(flags).listen = argv[++i];
    } else if (arg == "--watch-token" && has_value) {
      watch_options(flags).token = argv[++i];
      if (!gamepilot::valid_watch_token(watch_options(flags).token)) {
        return false;
      }
    } else if (arg == "--stream-fps" && has_value) {
      constexpr long kMaxStreamFps = 60;
      long fps = 0;
      if (!parse_in_range(argv[++i], 1, kMaxStreamFps, fps)) {
        return false;
      }
      flags.server.stream.fps = static_cast<double>(fps);
    } else if (arg == "--stream-width" && has_value) {
      long width = 0;
      if (!parse_in_range(argv[++i], gamepilot::kStreamMinWidth,
                          gamepilot::kStreamMaxWidth, width)) {
        return false;
      }
      flags.server.stream.width = static_cast<int>(width);
    } else if (arg == "--registry" && has_value) {
      flags.server.registry = argv[++i];
    } else if (arg == "--checkpoint" && has_value) {
      flags.server.checkpoint = argv[++i];
    } else if (arg == "--run-folder" && has_value) {
      flags.server.run_folder = argv[++i];
    } else if (arg == "--record") {
      flags.record = true;
    } else if (arg == "--no-record") {
      flags.record = false;
    } else if (arg == "--keepawake" && has_value) {
      long seconds = 0;
      if (!parse_in_range(argv[++i], 0, kMaxKeepAwakeS, seconds)) {
        return false;
      }
      flags.keepawake_s = static_cast<double>(seconds);
    } else if (arg == "--keepawake-key" && has_value) {
      flags.server.keepawake.key = argv[++i];
      if (gamepilot::button_mask(flags.server.keepawake.key) == 0) {
        return false;
      }
    } else if (arg == "--window-pid" && has_value) {
      long pid = 0;
      if (!parse_in_range(argv[++i], 1, std::numeric_limits<int>::max(),
                          pid)) {
        return false;
      }
      flags.window.pid = pid;
    } else if (arg == "--window-app" && has_value) {
      flags.window.app_path = argv[++i];
    } else if (arg == "--window-title" && has_value) {
      flags.window.title = argv[++i];
    } else if (arg == "--crop" && has_value) {
      const std::string_view crop = argv[++i];
      flags.view.find_crop = crop == "auto";
      if (!flags.view.find_crop) {
        flags.view.crop = gamepilot::parse_box(crop);
        if (!flags.view.crop) {
          return false;
        }
      }
    } else if (arg == "--stale-s" && has_value) {
      constexpr long kMaxStaleS = 3600;
      long seconds = 0;
      if (!parse_in_range(argv[++i], 1, kMaxStaleS, seconds)) {
        return false;
      }
      flags.view.stale_after_ms = static_cast<double>(seconds) * 1000;
    } else if (arg == "--name" && has_value) {
      flags.server.name = argv[++i];
      if (!gamepilot::valid_run_name(flags.server.name)) {
        return false;
      }
    } else if (arg == "--source" && has_value) {
      flags.server.source = argv[++i];
    } else if (arg == "--tail-log" && has_value) {
      flags.server.tail_log = argv[++i];
    } else if (arg == "--hub") {
      flags.hub = true;
    } else if (arg == "--fast") {
      flags.server.fast = true;
    } else if (arg == "--speed" && has_value) {
      if (!parse_speed(argv[++i], flags.server.speed)) {
        return false;
      }
    } else {
      return false;
    }
  }
  if (flags.hub) {
    return flags.backend.empty() && !flags.server.registry.empty();
  }
  backend_defaults(flags);
  if (flags.backend == "mgba") {
    return flags.mgba_port != 0;
  }
  // A live backend runs at its own rate.
  if (flags.server.speed != 1) {
    return false;
  }
  if (flags.backend == "view") {
    return valid_view_flags(flags);
  }
  if (flags.backend == "switch" && flags.board_check) {
    return flags.capture.empty() && flags.replay.empty();
  }
  if (flags.backend == "switch" && !flags.capture_check.empty()) {
    return flags.replay.empty() != flags.capture.empty() &&
           flags.serial.empty();
  }
  if (flags.backend == "switch") {
    return flags.replay.empty() != flags.capture.empty();
  }
  return false;
}

// How the frames are paced, for the "listening" line.
std::string pace_note(const gamepilot::ServerOptions& options) {
  if (options.fast) {
    return " (fast)";
  }
  if (options.speed == 1) {
    return "";
  }
  char note[32];
  std::snprintf(note, sizeof note, " (speed %gx)", options.speed);
  return note;
}

// Serves until a signal; returns the exit status.
int serve(gamepilot::Backend& backend, const gamepilot::ServerOptions& options,
          const gamepilot::Clock& clock) {
  gamepilot::Server server(backend, options, clock);
  // The watch line first: the runner reads both ports once it sees
  // "listening".
  if (options.watch) {
    std::fprintf(stderr, "daemon: watch page on http://%s:%u/\n",
                 options.watch->listen.c_str(),
                 static_cast<unsigned>(server.watch_port()));
    if (options.watch->listen != "127.0.0.1") {
      std::fprintf(stderr,
                   "daemon: the watch page is open to the network (--listen "
                   "%s): anyone who reaches it can watch; Stop takes the "
                   "run's token\n",
                   options.watch->listen.c_str());
    }
  }
  std::fprintf(stderr, "daemon: listening on 127.0.0.1:%u%s\n",
               static_cast<unsigned>(server.port()),
               pace_note(options).c_str());
  try {
    server.run(g_stop);
    return 0;
  } catch (const std::exception& error) {
    std::fprintf(stderr, "daemon: %s\n", error.what());
    return 1;
  }
}

int run_view(const Flags& flags) {
  const gamepilot::Clock clock;
  std::unique_ptr<gamepilot::FrameSource> source =
      flags.replay.empty() ? gamepilot::open_window_capture(flags.window)
                           : gamepilot::open_video_replay(flags.replay, clock);
  gamepilot::ViewBackend backend(std::move(source), clock, flags.view);
  std::fprintf(stderr,
               "daemon: view-only %s, %dx%d at %.2f fps; no input is taken\n",
               flags.server.source.c_str(), backend.info().width,
               backend.info().height, backend.info().frame_rate);
  return serve(backend, flags.server, clock);
}

int run_mgba(const Flags& flags) {
  const gamepilot::Clock clock;
  gamepilot::MgbaBackend backend(flags.mgba_port);
  std::fprintf(
      stderr, "daemon: mgba bridge on %u, game %s, held at frame %lld\n",
      static_cast<unsigned>(flags.mgba_port), backend.info().game_code.c_str(),
      static_cast<long long>(backend.seq()));
  const int status = serve(backend, flags.server, clock);
  std::fprintf(stderr,
               "daemon: stopped at frame %lld; %lld KEYS applied late\n",
               static_cast<long long>(backend.seq()),
               static_cast<long long>(backend.late_keys()));
  return status;
}

// Starts the board's session on --serial: prints what it said, or throws.
gamepilot::BoardInfo start_board(gamepilot::BoardSession& session) {
  const gamepilot::BoardInfo info = session.start();
  std::fprintf(stderr, "daemon: board %s; %s\n",
               gamepilot::describe(info).c_str(),
               gamepilot::describe(
                   session.first_status(gamepilot::pa::Milliseconds(2000)))
                   .c_str());
  return info;
}

// With no --serial, FakeSwitch's board: a dry run of the check.
int run_board_check(const Flags& flags) {
  gamepilot::BoardLog log;
  if (flags.serial.empty()) {
    const gamepilot::Clock clock;
    gamepilot::FakeSwitch board(clock);
    gamepilot::BoardSession session(board, log);
    start_board(session);
    return 0;
  }
  gamepilot::SerialBoardPort port(flags.serial);
  gamepilot::BoardSession session(port, log);
  start_board(session);
  return 0;
}

int run_capture_check(const Flags& flags) {
  const gamepilot::Clock clock;
  // With --replay, the video's first frame: a dry run of the check.
  const std::unique_ptr<gamepilot::FrameSource> source =
      flags.replay.empty()
          ? gamepilot::open_capture_card({.device = flags.capture})
          : gamepilot::open_video_replay(flags.replay, clock);
  const std::string& from =
      flags.replay.empty() ? flags.capture : flags.replay;
  cv::Mat frame;
  if (!source->read(frame) || frame.empty()) {
    std::fprintf(stderr, "daemon: no frame from %s\n", from.c_str());
    return 1;
  }
  gamepilot::save_png(flags.capture_check, frame);
  const gamepilot::GeometryCheck check = gamepilot::check_geometry(
      frame, flags.switch_options.viewport.picture);
  std::fprintf(stderr, "daemon: %dx%d at %.2f fps, saved %s; %s\n",
               frame.cols, frame.rows, source->frame_rate(),
               flags.capture_check.c_str(), gamepilot::describe(check).c_str());
  return check.ok ? 0 : 1;
}

// Inputs go to `session` (the board, or the fake one).
int serve_switch(const Flags& flags, const gamepilot::Clock& clock,
                 gamepilot::BoardSession& session, const char* inputs) {
  std::unique_ptr<gamepilot::FrameSource> source =
      flags.replay.empty()
          ? gamepilot::open_capture_card({.device = flags.capture})
          : gamepilot::open_video_replay(flags.replay, clock);
  gamepilot::SwitchBackend backend(std::move(source), session, clock,
                                   flags.switch_options);
  std::fprintf(stderr,
               "daemon: switch, %s %s, %dx%d at %.2f fps; inputs go to %s\n",
               flags.replay.empty() ? "capture" : "replay",
               flags.replay.empty() ? flags.capture.c_str()
                                    : flags.replay.c_str(),
               backend.info().width, backend.info().height,
               backend.info().frame_rate, inputs);
  const int status = serve(backend, flags.server, clock);
  backend.release();
  return status;
}

int run_switch(const Flags& flags) {
  const gamepilot::Clock clock;
  gamepilot::BoardLog log(/*quiet=*/flags.serial.empty());
  if (flags.serial.empty()) {
    gamepilot::FakeSwitch board(clock);
    gamepilot::BoardSession session(board, log);
    start_board(session);
    return serve_switch(flags, clock, session, "a fake controller board");
  }
  gamepilot::SerialBoardPort port(flags.serial);
  gamepilot::BoardSession session(port, log);
  start_board(session);
  return serve_switch(flags, clock, session, flags.serial.c_str());
}

// The hub, in a session of its own (no terminal's Ctrl-C or hangup reaches
// it); 0 when another hub has the port.
int run_hub(const Flags& flags) {
  gamepilot::HubOptions options;
  options.registry = flags.server.registry;
  // The registry is $GAMEPILOT_RUNS/.watch; the runs' results sit beside it.
  options.results = flags.server.registry + "/../RESULTS.tsv";
  options.runs = flags.server.registry + "/..";
  if (flags.server.watch) {
    options.listen = flags.server.watch->listen;
    options.port = flags.server.watch->port;
  }
#ifndef _WIN32
  setsid();
  std::signal(SIGHUP, SIG_IGN);
#endif
  std::optional<gamepilot::WatchHub> hub;
  try {
    hub.emplace(options);
  } catch (const std::runtime_error& error) {
    std::fprintf(stderr, "daemon: hub not started (%s): one already runs\n",
                 error.what());
    return 0;
  }
  std::fprintf(stderr, "daemon: hub on http://%s:%u/ for %s\n",
               options.listen.c_str(), static_cast<unsigned>(hub->port()),
               options.registry.c_str());
  hub->run(g_stop);
  return 0;
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
    if (flags.hub) {
      return run_hub(flags);
    }
    if (flags.backend == "mgba") {
      return run_mgba(flags);
    }
    if (flags.backend == "view") {
      return run_view(flags);
    }
    if (flags.board_check) {
      return run_board_check(flags);
    }
    if (!flags.capture_check.empty()) {
      return run_capture_check(flags);
    }
    return run_switch(flags);
  } catch (const std::exception& error) {
    std::fprintf(stderr, "daemon: %s\n", error.what());
    return 1;
  }
}
