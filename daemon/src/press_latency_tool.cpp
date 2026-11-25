// press_latency: the latency harness (press_latency.h) as a command.
//
//   press_latency --fake [--response-ms 50] [--fps 60] [--presses 20]
//                 [--hold-ms 100] [--gate-ms 50]
//   press_latency --serial PORT --capture DEVICE [--presses 100]
//                 [--hold-ms 100] [--keys start|a] [--gate-ms 50]
//
// --fake runs it on FakeSwitch: its screen turns bright `response-ms` after a
// press starts on the board, so the result should be that plus up to one
// frame. With --serial and --capture it runs on the console: the board's
// session (board_session.h, as a Pro Controller in the board's NS1 Wired Pro
// Controller mode, which it never changes) and the capture card. It presses
// Start by default, in the FRLG overworld: the start menu opens and closes at
// once, and the harness looks at the menu's side of the GBA picture. Exits 0
// when nothing was missed and the spread (p99 - median) is under --gate-ms (PR
// #44, F4).

#include <cstdio>
#include <cstdlib>
#include <exception>
#include <string>
#include <string_view>

#include "board_session.h"
#include "fake_switch.h"
#include "press_latency.h"
#include "switch_backend.h"
#include "video_capture.h"

namespace {

int usage() {
  std::fputs(
      "usage: press_latency --fake [--response-ms 50] [--fps 60] "
      "[--presses 20] [--hold-ms 100] [--gate-ms 50]\n"
      "       press_latency --serial PORT --capture DEVICE [--presses 100] "
      "[--hold-ms 100] [--keys start|a] [--gate-ms 50]\n",
      stderr);
  return 2;
}

bool parse_number(const char* text, double& value) {
  char* end = nullptr;
  value = std::strtod(text, &end);
  return end != text && *end == '\0' && value >= 0;
}

// GBA keys (rpc.cpp, button_mask).
constexpr gamepilot::KeyMask kGbaA = 1u << 0;
constexpr gamepilot::KeyMask kGbaStart = 1u << 3;

// The right third of the GBA picture, where FRLG's start menu opens.
constexpr gamepilot::Box kStartMenuSide{0.7, 0, 0.3, 1};

int report(const gamepilot::PressLatencyPlan& plan,
           const gamepilot::PressLatencyReport& report, double gate_ms) {
  const auto& l = report.latencies_ms;
  const double spread =
      gamepilot::percentile(l, 0.99) - gamepilot::percentile(l, 0.5);
  std::printf("presses %d, misses %d\n", plan.presses, report.misses);
  std::printf(
      "press -> changed frame ms: min %.1f, median %.1f, p90 %.1f, p99 "
      "%.1f, max %.1f\n",
      gamepilot::percentile(l, 0), gamepilot::percentile(l, 0.5),
      gamepilot::percentile(l, 0.9), gamepilot::percentile(l, 0.99),
      gamepilot::percentile(l, 1));
  const bool pass = report.misses == 0 && spread < gate_ms;
  std::printf("spread (p99 - median) ms: %.1f, gate %.0f: %s\n", spread,
              gate_ms, pass ? "PASS" : "FAIL");
  return pass ? 0 : 1;
}

int run_fake(const gamepilot::PressLatencyPlan& plan, double response_ms,
             double fps, double gate_ms) {
  const gamepilot::Clock clock;
  gamepilot::FakeSwitch board(clock);
  gamepilot::BoardLog log(/*quiet=*/true);
  gamepilot::BoardSession session(board, log);
  session.start();
  gamepilot::SwitchBackend backend(
      board.screen(fps, response_ms, cv::Size(320, 180)), session, clock,
      gamepilot::SwitchOptions{});
  const gamepilot::PressLatencyReport result =
      gamepilot::measure_press_latency(backend, clock, plan);
  std::printf(
      "press_latency (fake: response %.0f ms, %.0f fps, frame %.1f ms)\n",
      response_ms, fps, result.frame_ms);
  return report(plan, result, gate_ms);
}

int run_console(gamepilot::PressLatencyPlan plan, const std::string& serial,
                const std::string& capture, double gate_ms) {
  const gamepilot::Clock clock;
  gamepilot::SerialBoardPort port(serial);
  gamepilot::BoardLog log;
  gamepilot::BoardSession session(port, log);
  const gamepilot::BoardInfo info = session.start();
  std::printf("board: %s; %s\n", gamepilot::describe(info).c_str(),
              gamepilot::describe(
                  session.first_status(gamepilot::pa::Milliseconds(2000)))
                  .c_str());
  const gamepilot::SwitchOptions options;
  gamepilot::SwitchBackend backend(
      gamepilot::open_capture_card({.device = capture}), session, clock,
      options);
  plan.box = gamepilot::picture_box_to_frame(options.viewport, kStartMenuSide);
  const gamepilot::PressLatencyReport result =
      gamepilot::measure_press_latency(backend, clock, plan);
  backend.release();
  std::printf("press_latency (console: %dx%d at %.2f fps, frame %.1f ms)\n",
              backend.info().width, backend.info().height,
              backend.info().frame_rate, result.frame_ms);
  return report(plan, result, gate_ms);
}

}  // namespace

int main(int argc, char** argv) {
  bool fake = false;
  std::string serial;
  std::string capture;
  double response_ms = 50;
  double fps = 60;
  double presses = 0;
  double gate_ms = 50;
  gamepilot::PressLatencyPlan plan;
  plan.keys = kGbaStart;
  for (int i = 1; i < argc; i++) {
    const std::string_view arg = argv[i];
    const bool has_value = i + 1 < argc;
    if (arg == "--fake") {
      fake = true;
    } else if (arg == "--serial" && has_value) {
      serial = argv[++i];
    } else if (arg == "--capture" && has_value) {
      capture = argv[++i];
    } else if (arg == "--keys" && has_value) {
      const std::string_view keys = argv[++i];
      if (keys != "start" && keys != "a") {
        return usage();
      }
      plan.keys = keys == "a" ? kGbaA : kGbaStart;
    } else if (arg == "--response-ms" && has_value) {
      if (!parse_number(argv[++i], response_ms)) {
        return usage();
      }
    } else if (arg == "--fps" && has_value) {
      if (!parse_number(argv[++i], fps) || fps <= 0) {
        return usage();
      }
    } else if (arg == "--presses" && has_value) {
      if (!parse_number(argv[++i], presses) || presses < 1) {
        return usage();
      }
    } else if (arg == "--hold-ms" && has_value) {
      if (!parse_number(argv[++i], plan.hold_ms)) {
        return usage();
      }
    } else if (arg == "--gate-ms" && has_value) {
      if (!parse_number(argv[++i], gate_ms)) {
        return usage();
      }
    } else {
      return usage();
    }
  }
  const bool console = !serial.empty() && !capture.empty();
  if (fake == console) {
    return usage();
  }
  constexpr int kFakePresses = 20;
  constexpr int kConsolePresses = 100;
  plan.presses = presses > 0 ? static_cast<int>(presses)
                             : (fake ? kFakePresses : kConsolePresses);

  try {
    return fake ? run_fake(plan, response_ms, fps, gate_ms)
                : run_console(plan, serial, capture, gate_ms);
  } catch (const std::exception& error) {
    std::fprintf(stderr, "press_latency: %s\n", error.what());
    return 1;
  }
}
